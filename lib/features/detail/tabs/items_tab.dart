import 'package:flutter/material.dart';
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
  late List<Flashcard> _itemsCards;

  @override
  void initState() {
    super.initState();
    _itemsCards = List<Flashcard>.from(widget.cards);
  }

  @override
  void didUpdateWidget(covariant ItemsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 부모로부터 새로운 리스트가 내려오면 로컬 상태 동기화
    if (widget.cards != oldWidget.cards) {
      setState(() => _itemsCards = List<Flashcard>.from(widget.cards));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      itemCount: _itemsCards.length,
      itemBuilder: (context, index) {
        final card = _itemsCards[index];
        final rowNumber = index + 1;
        final String actualKey = card.key.trim().isNotEmpty ? card.key : "N/A";

        final Color flaggedColor = isDark
            ? const Color(0xFF4D4000)
            : const Color(0xFFFFF9C4);
        final Color normalColor = isDark
            ? AppColors.cDarkSurface
            : Colors.white;
        final Color cardBgColor = card.isFlagged ? flaggedColor : normalColor;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
          elevation: 0,
          color: cardBgColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isDark ? AppColors.cDarkBorder : AppColors.cSlate200,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              // EditCardPage로 이동하며 수정한 리스트를 돌려받음
              final List<Flashcard>? updatedCards = await Navigator.of(context)
                  .push<List<Flashcard>>(
                    MaterialPageRoute(
                      builder: (context) => EditCardPage(
                        initialCardIndex: index,
                        // 참조를 복사하여 전달하여 안전성 확보
                        cards: List<Flashcard>.from(_itemsCards),
                        setInfo: widget.setInfo,
                        driveService: widget.driveService,
                      ),
                    ),
                  );

              // 수정된 데이터가 반환되었을 경우 처리
              if (updatedCards != null) {
                setState(() {
                  _itemsCards = updatedCards;
                });
                // DetailPage의 상태를 업데이트하도록 콜백 호출
                widget.onRefresh(updatedCards);
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '#$rowNumber',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.cBrand600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          actualKey,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.cSlate500
                                : AppColors.cSlate400,
                            fontFamily: 'monospace',
                            letterSpacing: -0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (card.isFlagged)
                        const Icon(Icons.flag, size: 14, color: Colors.orange),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          card.front,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : AppColors.cSlate900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0),
                        child: Text(
                          '/',
                          style: TextStyle(
                            color: (isDark ? Colors.white : AppColors.cSlate900)
                                .withValues(alpha: 0.15),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          card.back,
                          style: TextStyle(
                            fontSize: 15,
                            color: isDark
                                ? AppColors.cSlate300
                                : AppColors.cSlate600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
