import 'package:flutter/material.dart';
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
    _wheelController = FixedExtentScrollController(
      initialItem: widget.currentPageIndex,
    );
    _filteredIndices = List.generate(widget.cards.length, (index) => index);
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
      _filteredIndices = widget.cards
          .asMap()
          .entries
          .where((entry) {
            final card = entry.value;
            final searchLower = query.toLowerCase();
            return card.front.toLowerCase().contains(searchLower) ||
                card.back.toLowerCase().contains(searchLower) ||
                card.key.toLowerCase().contains(searchLower);
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
    final double dialogHeight = size.height * 0.6;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: size.width * 0.9,
          height: dialogHeight,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              _buildHeader(),
              _buildSearchField(isDark),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _filteredIndices.isEmpty
                          ? const Center(child: Text("검색 결과가 없습니다."))
                          : ListWheelScrollView.useDelegate(
                              controller: _wheelController,
                              itemExtent: _itemExtent,
                              diameterRatio: 3.0,
                              // 수정된 커스텀 물리 적용
                              physics: const HighInertiaPhysics(
                                parent: BouncingScrollPhysics(),
                              ),
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
                    ),
                    if (_filteredIndices.length > 1)
                      Align(
                        alignment: Alignment.centerRight,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return GestureDetector(
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
                              child: Container(
                                width: 50,
                                height: double.infinity,
                                alignment: Alignment.centerRight,
                                child: _buildInteractiveTrack(
                                  isDark,
                                  constraints.maxHeight,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() => const Padding(padding: EdgeInsets.only(top: 20));

  Widget _buildInteractiveTrack(bool isDark, double trackHeight) {
    if (_filteredIndices.isEmpty) return const SizedBox.shrink();
    final double totalItems = _filteredIndices.length.toDouble();
    final double progress = (_scrollOffset / (totalItems - 1)).clamp(0.0, 1.0);

    return CustomPaint(
      size: Size(50, trackHeight),
      painter: HighlightTrackPainter(
        progress: progress,
        angleRange: math.pi / 2,
        radius: trackHeight * 0.2,
        yRange: trackHeight / 1.7,
        baseColor: isDark ? Colors.black : Colors.white,
        highlightColor: AppColors.cBrand600,
        baseStrokeWidth: 7.0,
        highlightStrokeWidth: 9.0,
      ),
    );
  }

  Widget _buildSearchField(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: "Search...",
          prefixIcon: const Icon(Icons.search, size: 20),
          filled: true,
          fillColor: isDark ? AppColors.cSlate800 : AppColors.cSlate50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
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
    final String actualKey = card.key.trim();
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
      child: GestureDetector(
        onTap: () {
          Navigator.pop(context);
          widget.onCardSelected(originalIndex);
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cSlate900 : AppColors.cSlate50,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Text(
                    '#${originalIndex + 1}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.cBrand600,
                    ),
                  ),
                  if (actualKey.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        actualKey,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9,
                          color: isDark ? Colors.white38 : Colors.black38,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 4),
                  if (card.isFlagged)
                    const Icon(Icons.flag, size: 12, color: Colors.orange),
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
                      textAlign: TextAlign.left,
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
    );
  }
}

// ---------------------------------------------------------
// [수정 완료] 작동하는 커스텀 물리 클래스
// ---------------------------------------------------------
// ---------------------------------------------------------
// [최종] 경계를 절대 넘지 않는 고관성 물리 엔진
// ---------------------------------------------------------
class HighInertiaPhysics extends FixedExtentScrollPhysics {
  const HighInertiaPhysics({super.parent});

  @override
  HighInertiaPhysics applyTo(ScrollPhysics? ancestor) {
    return HighInertiaPhysics(parent: buildParent(ancestor));
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    // 경계를 벗어난 상태면 부모(Bouncing) 로직으로 복귀
    if (position.outOfRange) {
      return super.createBallisticSimulation(position, velocity);
    }

    // 커스텀 시뮬레이션 반환
    return HighInertiaSimulation(
      position: position.pixels,
      velocity: velocity,
      minExtent: position.minScrollExtent,
      maxExtent: position.maxScrollExtent,
      friction: 0.005, // 미끄러짐 정도 조정 (0.001~0.01)
      tolerance: toleranceFor(position),
    );
  }
}

// 시뮬레이션의 위치 계산을 직접 제어하는 래퍼 클래스
class HighInertiaSimulation extends Simulation {
  final ClampingScrollSimulation _clamping;
  final double minExtent;
  final double maxExtent;

  HighInertiaSimulation({
    required double position,
    required double velocity,
    required this.minExtent,
    required this.maxExtent,
    required double friction,
    required Tolerance tolerance,
  }) : _clamping = ClampingScrollSimulation(
         position: position,
         velocity: velocity,
         friction: friction,
         tolerance: tolerance,
       );

  @override
  double x(double time) {
    // 시뮬레이션의 계산값이 범위를 넘으면 경계값에서 고정
    return _clamping.x(time).clamp(minExtent, maxExtent);
  }

  @override
  double dx(double time) {
    // 범위를 벗어나면 속도를 0으로 처리하여 시뮬레이션 종료 유도
    final double currentX = _clamping.x(time);
    if (currentX < minExtent || currentX > maxExtent) return 0.0;
    return _clamping.dx(time);
  }

  @override
  bool isDone(double time) {
    // 속도가 0이 되거나 범위를 벗어나면 종료
    return _clamping.isDone(time) ||
        _clamping.x(time) < minExtent ||
        _clamping.x(time) > maxExtent;
  }
}

// Painter 클래스는 기존과 동일하므로 유지함 (생략)
class HighlightTrackPainter extends CustomPainter {
  final double progress;
  final double angleRange;
  final double radius;
  final double yRange;
  final Color baseColor;
  final Color highlightColor;
  final double baseStrokeWidth;
  final double highlightStrokeWidth;

  HighlightTrackPainter({
    required this.progress,
    required this.angleRange,
    required this.radius,
    required this.yRange,
    required this.baseColor,
    required this.highlightColor,
    this.baseStrokeWidth = 5.0,
    this.highlightStrokeWidth = 7.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double centerX = size.width - 8.0;
    final double centerY = size.height / 2;

    final Paint basePaint = Paint()
      ..color = baseColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = baseStrokeWidth
      ..strokeCap = StrokeCap.round;

    final Path basePath = Path();
    for (double p = 0.0; p <= 1.0; p += 0.01) {
      final double angle = (p - 0.5) * angleRange;
      final double x = (1 - math.cos(angle)) * radius;
      final double y = math.sin(angle) * yRange + centerY;
      if (p == 0.0) {
        basePath.moveTo(centerX - x, y);
      } else {
        basePath.lineTo(centerX - x, y);
      }
    }
    canvas.drawPath(basePath, basePaint);

    final Paint highlightPaint = Paint()
      ..color = highlightColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = highlightStrokeWidth
      ..strokeCap = StrokeCap.round;

    final Path highlightPath = Path();
    final double hStart = (progress - 0.04).clamp(0.0, 1.0);
    final double hEnd = (progress + 0.04).clamp(0.0, 1.0);

    for (double p = hStart; p <= hEnd; p += 0.01) {
      final double angle = (p - 0.5) * angleRange;
      final double x = (1 - math.cos(angle)) * radius;
      final double y = math.sin(angle) * yRange + centerY;
      if (p == hStart) {
        highlightPath.moveTo(centerX - x, y);
      } else {
        highlightPath.lineTo(centerX - x, y);
      }
    }
    canvas.drawPath(highlightPath, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant HighlightTrackPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.radius != radius;
}
