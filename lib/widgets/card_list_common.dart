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
  }) {
    final query = searchQuery.toLowerCase();
    List<dynamic> result = [];
    bool skippingMode = false;
    int skipDepth = 0;

    for (int i = 0; i < allCards.length; i++) {
      final card = allCards[i];
      final bool isParent = checkHasChildren(i, allCards);
      final bool isCurrentTarget = (i == currentTargetIndex);

      if (query.isNotEmpty) {
        if (card.front.toLowerCase().contains(query) ||
            card.back.toLowerCase().contains(query) ||
            card.key.toLowerCase().contains(query)) {
          result.add(card);
        }
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
  });

  @override
  Widget build(BuildContext context) {
    bool hasActions = actions != null && actions!.isNotEmpty;

    return Transform.scale(
      scale: scale,
      child: Opacity(
        opacity: opacity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              CardListUtils.buildDepthSpacers(parent.groupDepth),
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Material(
                      color: (parent.isFlagged
                          ? (isDark
                                ? const Color(0xFFFFFF00).withValues(alpha: 0.1)
                                : const Color(0xFFFFF9C4))
                          : (isDark
                                ? AppColors.cSlate900
                                : AppColors.cSlate50)),
                      borderRadius: BorderRadius.circular(16),
                      elevation: isSelected ? 4 : 0,
                      shadowColor: Colors.black26,
                      child: InkWell(
                        onTap: onTap,
                        onLongPress: onLongPress,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          height: 88.0,
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.cBrand600
                                  : (isDark
                                        ? AppColors.cDarkBorder
                                        : AppColors.cSlate200),
                              width: isSelected ? 2.5 : 1.5,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: onToggle,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.cBrand600.withValues(
                                      alpha: 0.1,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    parent.isCollapsed
                                        ? Icons.chevron_right_rounded
                                        : Icons.expand_more_rounded,
                                    color: AppColors.cBrand600,
                                    size: 22,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12.0,
                                  ),
                                  child: isSimple
                                      ? _buildSimpleLayout(hasActions)
                                      : _buildDefaultLayout(hasActions),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (hasActions)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: actions!,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
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
        // 1️⃣ 상단 50% 영역 (Index + Key)
        Expanded(
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Row(
              children: [
                _buildIndexBadge(),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: hasActions ? 75 : 0),
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
        // 2️⃣ 하단 50% 영역 (Front | Back)
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
    const double indexWidth = 48.0;
    const double spacing = 0.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1️⃣ 상단 Row (Index + Front + Icons)
        Row(
          children: [
            SizedBox(
              width: indexWidth,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _buildIndexBadge(),
              ),
            ),
            const SizedBox(width: spacing),
            Expanded(
              child: Text(
                parent.front.replaceAll('\n', ' '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.cSlate900,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            if (!hasActions) ...[
              if (parent.remark.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(
                    Icons.history_edu_rounded,
                    size: 16,
                    color: AppColors.cBrand600,
                  ),
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
        const SizedBox(height: 4),
        // 2️⃣ 하단 Row (Back) - 위쪽 Front 텍스트와 시작점 일치시킴
        Padding(
          padding: const EdgeInsets.only(left: indexWidth + spacing),
          child: Text(
            parent.back.replaceAll('\n', ' '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.cSlate400 : AppColors.cSlate500,
              fontWeight: FontWeight.w500,
            ),
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
  });

  @override
  Widget build(BuildContext context) {
    bool hasActions = actions != null && actions!.isNotEmpty;

    return Transform.scale(
      scale: scale,
      child: Opacity(
        opacity: opacity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              CardListUtils.buildDepthSpacers(card.groupDepth),
              if (isParent) CardListUtils.buildDepthSpacers(1),
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Material(
                      color: (card.isFlagged
                          ? (isDark
                                ? const Color(0xFFFFFF00).withValues(alpha: 0.1)
                                : const Color(0xFFFFF9C4))
                          : (isDark
                                ? AppColors.cSlate900
                                : AppColors.cSlate50)),
                      borderRadius: BorderRadius.circular(16),
                      elevation: isSelected ? 4 : 0,
                      shadowColor: Colors.black26,
                      child: InkWell(
                        onTap: onTap,
                        onLongPress: onLongPress,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          height: 88.0,
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.cBrand600
                                  : (isDark
                                        ? AppColors.cDarkBorder
                                        : AppColors.cSlate200),
                              width: isSelected ? 2.5 : 1.5,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12.0,
                                  ),
                                  child: isSimple
                                      ? _buildSimpleLayout(hasActions)
                                      : _buildDefaultLayout(hasActions),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (hasActions)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: actions!,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
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
        // 1️⃣ 상단 50% 영역 (Index + Key)
        Expanded(
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Row(
              children: [
                _buildIndexBadge(),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: hasActions ? 75 : 0),
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
        // 2️⃣ 하단 50% 영역 (Front | Back)
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
    const double indexWidth = 48.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1️⃣ 상단 Row (Index + Front + Icons)
        Row(
          children: [
            SizedBox(
              width: indexWidth,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _buildIndexBadge(),
              ),
            ),
            Expanded(
              child: Text(
                card.front.replaceAll('\n', ' '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.cSlate900,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            if (!hasActions) ...[
              if (card.remark.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(
                    Icons.history_edu_rounded,
                    size: 16,
                    color: AppColors.cBrand600,
                  ),
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
        const SizedBox(height: 4),
        // 2️⃣ 하단 Row (Back) - 위쪽 Front 텍스트와 시작점 일치시킴
        Padding(
          padding: const EdgeInsets.only(left: indexWidth),
          child: Text(
            card.back.replaceAll('\n', ' '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.cSlate400 : AppColors.cSlate500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

// --- Widgets: 검색 필드 ---
class CardSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool isDark;
  final bool isPinned;
  final VoidCallback onPinToggled;

  const CardSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.isDark,
    required this.isPinned,
    required this.onPinToggled,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: "search".tr(),
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          controller.clear();
                          onChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark ? AppColors.cSlate800 : AppColors.cSlate100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: isPinned
                ? AppColors.cBrand600.withValues(alpha: 0.15)
                : (isDark ? AppColors.cSlate800 : AppColors.cSlate100),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onPinToggled,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: isPinned
                      ? Border.all(color: AppColors.cBrand600, width: 1.5)
                      : null,
                ),
                child: Icon(
                  isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                  size: 20,
                  color: isPinned
                      ? AppColors.cBrand600
                      : (isDark ? Colors.white38 : Colors.black38),
                ),
              ),
            ),
          ),
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
}
