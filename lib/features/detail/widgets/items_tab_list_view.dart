import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:bivium/models/flashcard.dart';
import 'package:bivium/core/theme.dart';

class ItemsTabListView extends StatelessWidget {
  final List<dynamic> displayItems;
  final List<Flashcard> allCards;
  final ScrollController scrollController;
  final int selectedDisplayIndex;
  final bool isCompact;
  final bool isDark;
  final double itemExtent;
  final Function(int) onSelectedItemChanged;
  final Function(Flashcard, int, int, bool) buildCardItem;
  final Function(Flashcard, int, bool) buildFolderHeader;

  const ItemsTabListView({
    super.key,
    required this.displayItems,
    required this.allCards,
    required this.scrollController,
    required this.selectedDisplayIndex,
    required this.isCompact,
    required this.isDark,
    required this.itemExtent,
    required this.onSelectedItemChanged,
    required this.buildCardItem,
    required this.buildFolderHeader,
  });

  @override
  Widget build(BuildContext context) {
    if (displayItems.isEmpty) {
      return Center(child: Text("no_search_results".tr()));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        void handleScroll(double localY) {
          if (scrollController.hasClients &&
              scrollController.position.hasContentDimensions) {
            final double trackHeight = constraints.maxHeight - 8;
            final double adjustedY = (localY - 4).clamp(0.0, trackHeight);
            final double scrollPercent = adjustedY / trackHeight;
            final double targetOffset =
                scrollPercent * scrollController.position.maxScrollExtent;
            scrollController.position.jumpTo(targetOffset);
          }
        }

        return Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: RawScrollbar(
                key: ValueKey('list_$isCompact'),
                controller: scrollController,
                minThumbLength: 40.0,
                mainAxisMargin: 4.0,
                thumbColor: AppColors.cBrand600.withValues(alpha: 0.8),
                thickness: 8,
                radius: const Radius.circular(10),
                thumbVisibility: true,
                interactive: true,
                pressDuration: Duration.zero,
                child: ListWheelScrollView.useDelegate(
                  key: ValueKey('list_$isCompact'),
                  controller: scrollController as FixedExtentScrollController,
                  itemExtent: itemExtent,
                  physics: const FixedExtentScrollPhysics(),
                  diameterRatio: 1000,
                  perspective: 0.000001,
                  overAndUnderCenterOpacity: 1.0,
                  onSelectedItemChanged: onSelectedItemChanged,
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: displayItems.length,
                    builder: (context, index) {
                      final item = displayItems[index];
                      if (item is Map && item['type'] == 'group_header') {
                        return buildFolderHeader(item['parent'], index, isDark);
                      }
                      final Flashcard card = item as Flashcard;
                      return buildCardItem(
                        card,
                        allCards.indexOf(card),
                        index,
                        isDark,
                      );
                    },
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) {
                  handleScroll(details.localPosition.dy);
                  HapticFeedback.lightImpact();
                },
                onVerticalDragUpdate: (details) {
                  handleScroll(details.localPosition.dy);
                },
                child: Container(
                  width: 30,
                  alignment: Alignment.centerRight,
                  color: Colors.transparent,
                  child: Container(
                    width: 6,
                    margin: const EdgeInsets.only(right: 7),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.black12,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
