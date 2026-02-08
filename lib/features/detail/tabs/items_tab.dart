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

  const ItemsTab({
    super.key,
    required this.cards,
    required this.setInfo,
    required this.driveService,
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

        // stats용 임시 ID가 아닌, 시트에서 불러온 실제 Key 값 사용
        final String actualKey = card.key.trim().isNotEmpty ? card.key : "N/A";

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
          elevation: 0,
          color: isDark ? AppColors.cDarkSurface : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isDark ? AppColors.cDarkBorder : AppColors.cSlate200,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              final updatedCards = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => EditCardPage(
                    initialCardIndex: index,
                    cards: _itemsCards,
                    setInfo: widget.setInfo,
                    driveService: widget.driveService,
                  ),
                ),
              );
              if (updatedCards != null && updatedCards is List<Flashcard>) {
                setState(() => _itemsCards = updatedCards);
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 시트 원본 Key 값 표시 영역
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
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Source: 1줄 제한
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
                      // Target: 1줄 제한
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
