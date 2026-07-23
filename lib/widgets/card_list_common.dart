import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:bivium/models/flashcard.dart';
import 'package:bivium/core/theme.dart';
import 'package:easy_localization/easy_localization.dart';

// --- Painter: 사이드 트랙 하이라이트 효과 ---
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

// --- Utils: 리스트 관리 및 UI 유틸리티 ---
class CardListUtils {
  static Widget buildDepthSpacers(int depth) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        depth,
        (index) => const SizedBox(
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
      ),
    );
  }

  static bool checkHasChildren(int index, List<Flashcard> cards) {
    if (index >= cards.length - 1) return false;
    return cards[index + 1].groupDepth > cards[index].groupDepth;
  }

  static List<dynamic> getDisplayItems({
    required List<Flashcard> allCards,
    required String searchQuery,
    int? currentTargetIndex,
    bool filterFlaggedOnly = false,
    bool filterWithRemarkOnly = false,
    bool filterWithoutRemarkOnly = false,
  }) {
    final query = searchQuery.toLowerCase();
    List<dynamic> result = [];
    bool skippingMode = false;
    int skipDepth = 0;

    for (int i = 0; i < allCards.length; i++) {
      final card = allCards[i];
      final bool isParent = checkHasChildren(i, allCards);
      final bool isCurrentTarget = (i == currentTargetIndex);

      // --- 조합 필터: 플래그 + Remark + 검색어 ---
      bool matchesQuery = true;
      if (query.isNotEmpty) {
        matchesQuery =
            card.front.toLowerCase().contains(query) ||
            card.back.toLowerCase().contains(query) ||
            card.key.toLowerCase().contains(query);
      }

      bool matchesFlag = true;
      if (filterFlaggedOnly) {
        matchesFlag = card.isFlagged;
      }

      bool matchesRemark = true;
      if (filterWithRemarkOnly) {
        matchesRemark = card.remark.isNotEmpty;
      }
      if (filterWithoutRemarkOnly) {
        matchesRemark = card.remark.isEmpty;
      }

      if (!matchesQuery || !matchesFlag || !matchesRemark) {
        continue;
      }

      if (skippingMode) {
        if (card.groupDepth > skipDepth) {
          if (!isCurrentTarget) continue;
        } else {
          skippingMode = false;
        }
      }

      if (isParent) {
        result.add({
          'type': 'group_header',
          'parent': card,
          'originalIndex': i,
        });
        if (card.isCollapsed) {
          skippingMode = true;
          skipDepth = card.groupDepth;
        }
      } else {
        result.add(card);
      }
    }
    return result;
  }

  static int findDisplayIndex({
    required int originalIdx,
    required List<dynamic> displayItems,
    required List<Flashcard> allCards,
  }) {
    for (int i = 0; i < displayItems.length; i++) {
      final item = displayItems[i];
      if (item is Flashcard && allCards.indexOf(item) == originalIdx) {
        return i;
      }
      if (item is Map && item['originalIndex'] == originalIdx) {
        return i;
      }
    }
    return 0;
  }
}

// --- Widgets: 폴더 헤더 (그룹) ---
class FlashcardFolderHeader extends StatelessWidget {
  final Flashcard parent;
  final int index;
  final int originalIndex;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final List<Widget>? actions;
  final double scale;
  final double opacity;
  final VoidCallback? onLongPress;
  final bool isSimple;
  final String? editingCellId;
  final Function(String?) onStartEditing;
  final Function(Flashcard, int, String, String) onUpdateCell;

  const FlashcardFolderHeader({
    super.key,
    required this.parent,
    required this.index,
    required this.originalIndex,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
    required this.onToggle,
    this.actions,
    this.scale = 1.0,
    this.opacity = 1.0,
    this.onLongPress,
    this.isSimple = false,
    this.editingCellId,
    required this.onStartEditing,
    required this.onUpdateCell,
  });

  @override
  Widget build(BuildContext context) {
    bool hasActions = actions != null && actions!.isNotEmpty;

    return Container(
      // 최상위 컨테이너에 상하 테두리 적용하여 가로로 길게 늘림
      decoration: BoxDecoration(
        border: isSelected
            ? const Border(
                top: BorderSide(color: AppColors.cBrand600, width: 2.0),
                bottom: BorderSide(color: AppColors.cBrand600, width: 2.0),
              )
            : Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.cDarkBorder : AppColors.cSlate200,
                  width: 0.8,
                ),
              ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: CardListUtils.buildDepthSpacers(parent.groupDepth),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onToggle,
                child: Container(
                  width: 28,
                  alignment: Alignment.center,
                  child: Icon(
                    parent.isCollapsed
                        ? Icons.chevron_right_rounded
                        : Icons.expand_more_rounded,
                    color: AppColors.cBrand600,
                    size: 20,
                  ),
                ),
              ),
            ),
            Container(
              width: 1.5,
              color: AppColors.cBrand600.withValues(alpha: 0.5),
            ),
            Expanded(
              child: InkWell(
                onTap: onTap,
                onDoubleTap: () {},
                onLongPress: onLongPress,
                child: Ink(
                  decoration: BoxDecoration(
                    color: parent.isFlagged
                        ? (isDark
                              ? const Color(0xFFFFFF00).withValues(alpha: 0.1)
                              : const Color(0xFFFFF9C4))
                        : (isDark ? AppColors.cSlate900 : AppColors.cSlate50),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Stack(
                      children: [
                        Container(
                          constraints: isSimple
                              ? null
                              : const BoxConstraints(minHeight: 85),
                          padding: EdgeInsets.only(
                            left: isSimple ? 8 : 12,
                            top: isSimple ? 6 : 12,
                            bottom: isSimple ? 6 : 12,
                            right: hasActions
                                ? (isSimple ? 60 : 12)
                                : (isSimple ? 8 : 12),
                          ),
                          child: isSimple
                              ? _buildSimpleLayout(hasActions)
                              : _buildDefaultLayout(hasActions),
                        ),
                        if (hasActions)
                          Positioned(
                            top: isSimple ? 0 : 6,
                            bottom: isSimple ? 0 : null,
                            right: 0,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: actions!
                                  .map(
                                    (action) => GestureDetector(
                                      onTap: () {},
                                      behavior: HitTestBehavior.opaque,
                                      child: action,
                                    ),
                                  )
                                  .toList(),
                            ),
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

  Widget _buildIndexBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.cBrand600.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Text(
        '#${originalIndex + 1}',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: AppColors.cBrand600,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  Widget _buildDefaultLayout(bool hasActions) {
    return Column(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Row(
              children: [
                _buildIndexBadge(),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: hasActions ? 60 : 0),
                    child: Text(
                      parent.key,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.cSlate400
                            : AppColors.cSlate500,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (!hasActions) ...[
                  if (parent.remark.isNotEmpty)
                    const Icon(
                      Icons.history_edu_rounded,
                      size: 16,
                      color: AppColors.cBrand600,
                    ),
                  if (parent.isFlagged)
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.flag_rounded,
                        size: 16,
                        color: Colors.orange,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Align(
            alignment: Alignment.topLeft,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    parent.front.replaceAll('\n', ' '),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.cSlate900,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('|', style: TextStyle(color: Colors.grey)),
                ),
                Expanded(
                  child: Text(
                    parent.back.replaceAll('\n', ' '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? AppColors.cSlate300 : AppColors.cSlate600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleLayout(bool hasActions) {
    final Color borderColor = isDark ? Colors.white10 : Colors.black12;

    return Row(
      children: [
        _buildIndexBadge(),
        const SizedBox(width: 8),
        Expanded(
          flex: 4,
          child: Container(
            height: double.infinity,
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: borderColor)),
            ),
            child: CompactEditableCell(
              text: parent.front,
              isEditing: editingCellId == '${originalIndex}_parent_front',
              onStartEditing: () =>
                  onStartEditing('${originalIndex}_parent_front'),
              onUpdate: (val) {
                onUpdateCell(parent, originalIndex, 'front', val);
                onStartEditing(null);
              },
              isDark: isDark,
              textAlign: TextAlign.center,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.cSlate900,
              ),
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: Container(
            height: double.infinity,
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: borderColor)),
            ),
            child: CompactEditableCell(
              text: parent.back,
              isEditing: editingCellId == '${originalIndex}_parent_back',
              onStartEditing: () =>
                  onStartEditing('${originalIndex}_parent_back'),
              onUpdate: (val) {
                onUpdateCell(parent, originalIndex, 'back', val);
                onStartEditing(null);
              },
              isDark: isDark,
              textAlign: TextAlign.center,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.cSlate400 : AppColors.cSlate500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        Container(
          width: 36,
          height: double.infinity,
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: borderColor)),
          ),
          child: Center(
            child: !hasActions
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (parent.remark.isNotEmpty)
                        const Icon(
                          Icons.history_edu_rounded,
                          size: 14,
                          color: AppColors.cBrand600,
                        ),
                      if (parent.isFlagged)
                        const Icon(
                          Icons.flag_rounded,
                          size: 14,
                          color: Colors.orange,
                        ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

// --- Widgets: 플래시카드 아이템 ---
class FlashcardListItem extends StatelessWidget {
  final Flashcard card;
  final int originalIndex;
  final int index;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;
  final List<Widget>? actions;
  final double scale;
  final double opacity;
  final bool isParent;
  final VoidCallback? onLongPress;
  final bool isSimple;
  final String? editingCellId;
  final Function(String?) onStartEditing;
  final Function(Flashcard, int, String, String) onUpdateCell;

  const FlashcardListItem({
    super.key,
    required this.card,
    required this.originalIndex,
    required this.index,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
    this.actions,
    this.scale = 1.0,
    this.opacity = 1.0,
    required this.isParent,
    this.onLongPress,
    this.isSimple = false,
    this.editingCellId,
    required this.onStartEditing,
    required this.onUpdateCell,
  });

  @override
  Widget build(BuildContext context) {
    bool hasActions = actions != null && actions!.isNotEmpty;

    return Container(
      // 최상위 컨테이너에 상하 테두리 적용하여 가로로 길게 늘림
      decoration: BoxDecoration(
        border: isSelected
            ? const Border(
                top: BorderSide(color: AppColors.cBrand600, width: 2.0),
                bottom: BorderSide(color: AppColors.cBrand600, width: 2.0),
              )
            : Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.cDarkBorder : AppColors.cSlate200,
                  width: 0.8,
                ),
              ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CardListUtils.buildDepthSpacers(card.groupDepth),
                  if (isParent) CardListUtils.buildDepthSpacers(1),
                ],
              ),
            ),
            Container(
              width: 1,
              color: isDark ? AppColors.cDarkBorder : AppColors.cSlate200,
            ),
            Expanded(
              child: InkWell(
                onTap: onTap,
                onDoubleTap: () {},
                onLongPress: onLongPress,
                child: Ink(
                  decoration: BoxDecoration(
                    color: card.isFlagged
                        ? (isDark
                              ? const Color(0xFFFFFF00).withValues(alpha: 0.1)
                              : const Color(0xFFFFF9C4))
                        : (isDark ? AppColors.cSlate900 : AppColors.cSlate50),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Stack(
                      children: [
                        Container(
                          constraints: isSimple
                              ? null
                              : const BoxConstraints(minHeight: 85),
                          padding: EdgeInsets.only(
                            left: isSimple ? 8 : 12,
                            top: isSimple ? 6 : 12,
                            bottom: isSimple ? 6 : 12,
                            right: hasActions
                                ? (isSimple ? 60 : 12)
                                : (isSimple ? 8 : 12),
                          ),
                          child: isSimple
                              ? _buildSimpleLayout(hasActions)
                              : _buildDefaultLayout(hasActions),
                        ),
                        if (hasActions)
                          Positioned(
                            top: isSimple ? 0 : 6,
                            bottom: isSimple ? 0 : null,
                            right: 0,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: actions!
                                  .map(
                                    (action) => GestureDetector(
                                      onTap: () {},
                                      behavior: HitTestBehavior.opaque,
                                      child: action,
                                    ),
                                  )
                                  .toList(),
                            ),
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

  Widget _buildIndexBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.cBrand600.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Text(
        '#${originalIndex + 1}',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: AppColors.cBrand600,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  Widget _buildDefaultLayout(bool hasActions) {
    return Column(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Row(
              children: [
                _buildIndexBadge(),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: hasActions ? 60 : 0),
                    child: Text(
                      card.key,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.cSlate400
                            : AppColors.cSlate500,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (!hasActions) ...[
                  if (card.remark.isNotEmpty)
                    const Icon(
                      Icons.history_edu_rounded,
                      size: 16,
                      color: AppColors.cBrand600,
                    ),
                  if (card.isFlagged)
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.flag_rounded,
                        size: 16,
                        color: Colors.orange,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Align(
            alignment: Alignment.topLeft,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    card.front.replaceAll('\n', ' '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.cSlate900,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('|', style: TextStyle(color: Colors.grey)),
                ),
                Expanded(
                  child: Text(
                    card.back.replaceAll('\n', ' '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? AppColors.cSlate300 : AppColors.cSlate600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleLayout(bool hasActions) {
    final Color borderColor = isDark ? Colors.white10 : Colors.black12;

    return Row(
      children: [
        _buildIndexBadge(),
        const SizedBox(width: 8),
        Expanded(
          flex: 4,
          child: Container(
            height: double.infinity,
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: borderColor)),
            ),
            child: CompactEditableCell(
              text: card.front,
              isEditing: editingCellId == '${originalIndex}_front',
              onStartEditing: () => onStartEditing('${originalIndex}_front'),
              onUpdate: (val) {
                onUpdateCell(card, originalIndex, 'front', val);
                onStartEditing(null);
              },
              isDark: isDark,
              textAlign: TextAlign.center,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.cSlate900,
              ),
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: Container(
            height: double.infinity,
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: borderColor)),
            ),
            child: CompactEditableCell(
              text: card.back,
              isEditing: editingCellId == '${originalIndex}_back',
              onStartEditing: () => onStartEditing('${originalIndex}_back'),
              onUpdate: (val) {
                onUpdateCell(card, originalIndex, 'back', val);
                onStartEditing(null);
              },
              isDark: isDark,
              textAlign: TextAlign.center,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.cSlate400 : AppColors.cSlate500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        Container(
          width: 36,
          height: double.infinity,
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: borderColor)),
          ),
          child: Center(
            child: !hasActions
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (card.remark.isNotEmpty)
                        const Icon(
                          Icons.history_edu_rounded,
                          size: 14,
                          color: AppColors.cBrand600,
                        ),
                      if (card.isFlagged)
                        const Icon(
                          Icons.flag_rounded,
                          size: 14,
                          color: Colors.orange,
                        ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

// --- Widgets: 검색 필드 ---
class CardSearchField extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool isDark;
  final bool isPinned;
  final VoidCallback onPinToggled;
  final bool showPin;
  final bool showCompactToggle;
  final List<Widget>? additionalActions;

  const CardSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.isDark,
    required this.isPinned,
    required this.onPinToggled,
    this.showPin = true,
    this.showCompactToggle = false,
    this.additionalActions,
  });

  @override
  State<CardSearchField> createState() => _CardSearchFieldState();
}

class _CardSearchFieldState extends State<CardSearchField> {
  bool _isCompact = false;

  @override
  void initState() {
    super.initState();
    _isCompact = CompactModeManager().isCompact;
    CompactModeManager().addListener(_onCompactChanged);
  }

  void _onCompactChanged() {
    final compact = CompactModeManager().isCompact;
    if (_isCompact != compact) {
      setState(() => _isCompact = compact);
    }
  }

  @override
  void dispose() {
    CompactModeManager().removeListener(_onCompactChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: widget.controller,
              onChanged: widget.onChanged,
              decoration: InputDecoration(
                hintText: "search".tr(),
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: widget.controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          widget.controller.clear();
                          widget.onChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: widget.isDark
                    ? AppColors.cSlate800
                    : AppColors.cSlate100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (widget.showPin)
            Material(
              color: widget.isPinned
                  ? AppColors.cBrand600.withValues(alpha: 0.15)
                  : (widget.isDark ? AppColors.cSlate800 : AppColors.cSlate100),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: widget.onPinToggled,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: widget.isPinned
                        ? Border.all(color: AppColors.cBrand600, width: 1.5)
                        : null,
                  ),
                  child: Icon(
                    widget.isPinned
                        ? Icons.push_pin_rounded
                        : Icons.push_pin_outlined,
                    size: 20,
                    color: widget.isPinned
                        ? AppColors.cBrand600
                        : (widget.isDark ? Colors.white38 : Colors.black38),
                  ),
                ),
              ),
            ),
          if (widget.showCompactToggle) ...[
            const SizedBox(width: 8),
            Material(
              color: _isCompact
                  ? AppColors.cBrand600.withValues(alpha: 0.15)
                  : (widget.isDark ? AppColors.cSlate800 : AppColors.cSlate100),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => CompactModeManager().toggle(),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: _isCompact
                        ? Border.all(color: AppColors.cBrand600, width: 1.5)
                        : null,
                  ),
                  child: Icon(
                    _isCompact
                        ? Icons.view_headline_rounded
                        : Icons.view_agenda_rounded,
                    size: 20,
                    color: _isCompact
                        ? AppColors.cBrand600
                        : (widget.isDark ? Colors.white38 : Colors.black38),
                  ),
                ),
              ),
            ),
          ],
          if (widget.additionalActions != null) ...widget.additionalActions!,
        ],
      ),
    );
  }
}

// --- Manager: 검색 상태 관리 ---
class SearchManager extends ChangeNotifier {
  static final SearchManager _instance = SearchManager._internal();
  factory SearchManager() => _instance;
  SearchManager._internal();

  String _query = '';
  bool _isPinned = false;

  String get query => _query;
  bool get isPinned => _isPinned;

  void update(String q, bool pinned) {
    if (_query == q && _isPinned == pinned) return;
    _query = q;
    _isPinned = pinned;
    notifyListeners();
  }

  void resetIfUnpinned() {
    if (!_isPinned && _query.isNotEmpty) {
      _query = '';
      notifyListeners();
    }
  }

  void reset() {
    if (_query.isNotEmpty || _isPinned) {
      _query = '';
      _isPinned = false;
      notifyListeners();
    }
  }

  void showSearchDialog(
    BuildContext context,
    List<Flashcard> cards,
    void Function(int) onSelected,
  ) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('search'.tr()),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'search'.tr(),
                        prefixIcon: const Icon(Icons.search),
                      ),
                      onChanged: (value) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 200,
                      width: double.maxFinite,
                      child: ListView.builder(
                        itemCount: cards.length,
                        itemBuilder: (context, index) {
                          final card = cards[index];
                          final query = controller.text.toLowerCase();
                          if (query.isNotEmpty &&
                              !card.front.toLowerCase().contains(query) &&
                              !card.back.toLowerCase().contains(query) &&
                              !card.key.toLowerCase().contains(query)) {
                            return const SizedBox.shrink();
                          }
                          return ListTile(
                            title: Text(
                              card.front,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              card.back,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () {
                              onSelected(index);
                              Navigator.of(context).pop();
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('cancel'.tr()),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// --- Manager: 컴팩트 모드 상태 관리 ---
class CompactModeManager extends ChangeNotifier {
  static final CompactModeManager _instance = CompactModeManager._internal();
  factory CompactModeManager() => _instance;
  CompactModeManager._internal();

  bool _isCompact = false;

  bool get isCompact => _isCompact;

  void toggle() {
    _isCompact = !_isCompact;
    notifyListeners();
  }

  void set(bool value) {
    if (_isCompact == value) return;
    _isCompact = value;
    notifyListeners();
  }

  bool isSimple(int keyColIdx) => keyColIdx == -1 || _isCompact;
}

class CompactEditableCell extends StatefulWidget {
  final String text;
  final bool isEditing;
  final VoidCallback onStartEditing;
  final Function(String) onUpdate;
  final bool isDark;
  final TextStyle style;
  final TextAlign textAlign;
  final EdgeInsetsGeometry padding;

  const CompactEditableCell({
    super.key,
    required this.text,
    required this.isEditing,
    required this.onStartEditing,
    required this.onUpdate,
    required this.isDark,
    required this.style,
    this.textAlign = TextAlign.left,
    this.padding = EdgeInsets.zero,
  });

  @override
  State<CompactEditableCell> createState() => _CompactEditableCellState();
}

class _CompactEditableCellState extends State<CompactEditableCell> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.text);
    _focusNode = FocusNode();
    if (widget.isEditing) {
      _focusNode.requestFocus();
    }
  }

  @override
  void didUpdateWidget(CompactEditableCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isEditing && !oldWidget.isEditing) {
      _controller.text = widget.text;
      _focusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEditing) {
      return Container(
        color: widget.isDark
            ? AppColors.cSlate800
            : Colors.blue.withValues(alpha: 0.1),
        padding: widget.padding,
        alignment: Alignment.center,
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          style: widget.style.copyWith(height: 1.2),
          textAlign: widget.textAlign,
          maxLines: null,
          expands: true, // 시트처럼 셀 전체를 필드로 사용
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.zero,
            border: InputBorder.none,
          ),
          onSubmitted: (val) => widget.onUpdate(val),
          onTapOutside: (_) => widget.onUpdate(_controller.text),
        ),
      );
    }
    return InkWell(
      onTap: widget.onStartEditing,
      child: Container(
        padding: widget.padding,
        alignment: widget.textAlign == TextAlign.center
            ? Alignment.center
            : (widget.textAlign == TextAlign.right
                  ? Alignment.centerRight
                  : Alignment.centerLeft),
        child: Text(
          widget.text.replaceAll('\n', ' '),
          style: widget.style,
          textAlign: widget.textAlign,
          maxLines: 2, // 간소화보기에서도 최대 2줄까지는 보이도록 허용
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
