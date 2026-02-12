import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bivium/models/flashcard.dart';
import 'package:bivium/services/google_drive_service.dart';
import '../../../core/theme.dart';
import '../edit_card_page.dart';

class ItemsTab extends StatefulWidget {
  final List<Flashcard> cards;
  final FlashcardSet setInfo;
  final GoogleDriveService driveService;
  final ScrollController? scrollController;
  final Function(List<Flashcard>?) onRefresh;

  const ItemsTab({
    super.key,
    required this.cards,
    required this.setInfo,
    required this.driveService,
    required this.onRefresh,
    this.scrollController,
  });

  @override
  State<ItemsTab> createState() => _ItemsTabState();
}

class _ItemsTabState extends State<ItemsTab> {
  late List<Flashcard> _filteredCards;
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<double> _scrollProgress = ValueNotifier(0.0);

  // 하이라이트 상태 관리를 위한 변수
  int? _highlightedIndex;

  @override
  void initState() {
    super.initState();
    _filteredCards = widget.cards;
    widget.scrollController?.addListener(_updateProgress);
  }

  void _updateProgress() {
    if (widget.scrollController!.hasClients) {
      final pos = widget.scrollController!.position;
      final double progress =
          (pos.pixels / (pos.maxScrollExtent > 0 ? pos.maxScrollExtent : 1))
              .clamp(0.0, 1.0);
      _scrollProgress.value = progress;
    }
  }

  void _runFilter(String query) {
    setState(() {
      final q = query.toLowerCase();
      _filteredCards = query.isEmpty
          ? widget.cards
          : widget.cards
                .where(
                  (c) =>
                      c.front.toLowerCase().contains(q) ||
                      c.back.toLowerCase().contains(q) ||
                      c.key.toLowerCase().contains(q),
                )
                .toList();
    });
  }

  void _handleJump(Offset localPosition, double height) {
    final controller = widget.scrollController;
    if (controller == null ||
        !controller.hasClients ||
        _filteredCards.isEmpty) {
      return;
    }

    final double maxScroll = controller.position.maxScrollExtent;
    final double ratio = (localPosition.dy / height).clamp(0.0, 1.0);
    controller.position.jumpTo(ratio * maxScroll);
    HapticFeedback.selectionClick();
  }

  @override
  void dispose() {
    widget.scrollController?.removeListener(_updateProgress);
    _searchController.dispose();
    _scrollProgress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        _buildSearchField(isDark),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  RepaintBoundary(
                    child: ListView.builder(
                      controller: widget.scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(0, 8, 8, 24),
                      itemCount: _filteredCards.length,
                      itemExtent: 82.0,
                      itemBuilder: (context, index) =>
                          _buildCardItem(_filteredCards[index], isDark, index),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: 40,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragUpdate: (d) =>
                          _handleJump(d.localPosition, constraints.maxHeight),
                      onVerticalDragDown: (d) =>
                          _handleJump(d.localPosition, constraints.maxHeight),
                      child: _buildIndicatorTrack(isDark),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCardItem(Flashcard card, bool isDark, int index) {
    final int originalIndex = widget.cards.indexOf(card);
    final bool isHighlighted = _highlightedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
      child: Stack(
        children: [
          Material(
            color: card.isFlagged
                ? (isDark ? const Color(0xFF4D4000) : const Color(0xFFFFF9C4))
                : (isDark ? AppColors.cDarkSurface : Colors.white),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                HapticFeedback.lightImpact();
                final dynamic result = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => EditCardPage(
                      initialCardIndex: originalIndex,
                      cards: List<Flashcard>.from(widget.cards),
                      setInfo: widget.setInfo,
                      driveService: widget.driveService,
                    ),
                  ),
                );

                if (result != null && result is Map) {
                  final updatedCards = result['cards'] as List<Flashcard>;
                  final lastIndex = result['lastIndex'] as int;
                  widget.onRefresh(updatedCards);

                  // 스크롤 이동과 하이라이트 시작 타이밍 맞추기
                  if (widget.scrollController?.hasClients ?? false) {
                    widget.scrollController!.jumpTo(lastIndex * 82.0);
                  }

                  // 스크롤이 끝난 직후 하이라이트 트리거
                  setState(() => _highlightedIndex = lastIndex);

                  // 100ms 유지 후 스르륵 사라짐 (400ms 애니메이션 시작)
                  Future.delayed(const Duration(milliseconds: 100), () {
                    if (mounted) setState(() => _highlightedIndex = null);
                  });
                }
              },
              child: Container(
                height: 82.0,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isDark ? AppColors.cDarkBorder : AppColors.cSlate200,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _buildCardContent(card, originalIndex, isDark),
              ),
            ),
          ),

          // [중요] if 문을 제거하고 색상값으로만 제어해야 스르륵 소멸함
          IgnorePointer(
            child: AnimatedContainer(
              // 나타날 땐 즉시(0), 사라질 땐 부드럽게(400ms)
              duration: isHighlighted
                  ? Duration.zero
                  : const Duration(milliseconds: 400),
              curve: Curves.easeOut,
              height: 82.0,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                // 투명도 0.0과 0.3 사이를 보간하여 애니메이션 생성
                color: Theme.of(
                  context,
                ).highlightColor.withValues(alpha: isHighlighted ? 0.3 : 0.0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardContent(Flashcard card, int originalIndex, bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '#${originalIndex + 1}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.cBrand600,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      card.key.isEmpty ? "" : card.key,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (card.isFlagged) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.flag, size: 14, color: Colors.orange),
                  ],
                ],
              ),
            ),
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
                  color: isDark ? AppColors.cSlate400 : AppColors.cSlate600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIndicatorTrack(bool isDark) {
    return ValueListenableBuilder<double>(
      valueListenable: _scrollProgress,
      builder: (context, progress, _) {
        return Container(
          margin: const EdgeInsets.only(right: 8),
          alignment: Alignment.centerRight,
          child: Container(
            width: 6,
            height: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : Colors.black12,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Align(
              alignment: Alignment(0, (progress * 2) - 1),
              child: Container(
                width: 6,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.cBrand600,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchField(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: _searchController,
        onChanged: _runFilter,
        decoration: InputDecoration(
          hintText: "Search...",
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
}
