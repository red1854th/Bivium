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
                      // 스크롤 바 공간 확보를 위해 우측 패딩을 32로 조정
                      padding: const EdgeInsets.fromLTRB(0, 8, 8, 24),
                      itemCount: _filteredCards.length,
                      itemExtent: 82.0,
                      itemBuilder: (context, index) =>
                          _buildCardItem(_filteredCards[index], isDark),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: 40, // 터치 감지 영역 유지
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

  Widget _buildIndicatorTrack(bool isDark) {
    return ValueListenableBuilder<double>(
      valueListenable: _scrollProgress,
      builder: (context, progress, _) {
        return Container(
          // 우측 여백을 8로 늘려 벽에서 띄움
          margin: const EdgeInsets.only(right: 8),
          alignment: Alignment.centerRight,
          child: Container(
            width: 6, // 두께를 6으로 확장
            height: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : Colors.black12,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Align(
              alignment: Alignment(0, (progress * 2) - 1),
              child: Container(
                width: 6, // 인디케이터 두께 6
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
              ? Colors.white.withOpacity(0.05)
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

  Widget _buildCardItem(Flashcard card, bool isDark) {
    final int originalIndex = widget.cards.indexOf(card);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
      child: Material(
        color: card.isFlagged
            ? (isDark ? const Color(0xFF4D4000) : const Color(0xFFFFF9C4))
            : (isDark ? AppColors.cDarkSurface : Colors.white),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            HapticFeedback.lightImpact();
            final List<Flashcard>? updated = await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => EditCardPage(
                  initialCardIndex: originalIndex,
                  cards: List<Flashcard>.from(widget.cards),
                  setInfo: widget.setInfo,
                  driveService: widget.driveService,
                ),
              ),
            );
            if (updated != null) widget.onRefresh(updated);
          },
          child: Container(
            padding: const EdgeInsets.only(
              top: 11.0,
              bottom: 10.0,
              left: 16.0,
              right: 16.0,
            ),
            decoration: BoxDecoration(
              border: Border.all(
                color: isDark ? AppColors.cDarkBorder : AppColors.cSlate200,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                    Expanded(
                      child: Text(
                        card.key.isEmpty ? "N/A" : card.key,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
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
      ),
    );
  }
}
