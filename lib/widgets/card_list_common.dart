import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:bivium/models/flashcard.dart';
import 'package:bivium/core/theme.dart';
import 'package:easy_localization/easy_localization.dart';

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
      final bool isParent = CardListUtils.checkHasChildren(i, allCards);
      final bool isCurrentTarget = (i == currentTargetIndex);

      // 1. 검색 필터링 (검색 중에는 폴더 구조 무시)
      if (query.isNotEmpty) {
        if (!(card.front.toLowerCase().contains(query) ||
            card.back.toLowerCase().contains(query) ||
            card.key.toLowerCase().contains(query))) {
          continue;
        }
      } else {
        // 2. 접기 로직 (검색 중이 아닐 때만 작동)
        if (skippingMode) {
          if (card.groupDepth > skipDepth) {
            if (!isCurrentTarget) continue;
          } else {
            skippingMode = false;
          }
        }
      }

      // 3. 상위 폴더(그룹) 헤더 추가
      if (isParent && query.isEmpty) {
        result.add({
          'type': 'group_header',
          'parent': card,
          'originalIndex': i,
        });

        // 폴더가 접혀있으면 하위 항목 스킵 모드 진입
        if (card.isCollapsed) {
          skippingMode = true;
          skipDepth = card.groupDepth;
        }
        // [수정] 헤더가 곧 카드 접근점이므로, 아래에서 카드 본체를 중복으로 추가하지 않음
        continue;
      }

      // 4. 일반 카드 추가
      result.add(card);
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

class FlashcardFolderHeader extends StatelessWidget {
  final Flashcard parent;
  final int index;
  final int originalIndex; // 원본 인덱스 추가
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final List<Widget>? actions;
  final double scale;
  final double opacity;
  final VoidCallback? onLongPress;

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
                                ? const Color(0xFF383000)
                                : const Color(0xFFFFFDE7))
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
                              // 1. 화살표 토글 영역 (기존 폴더 아이콘 대체)
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: onToggle,
                                  borderRadius: BorderRadius.circular(100),
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
                              ),
                              const SizedBox(width: 12),
                              // 2. 텍스트 영역
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 상단 정보 (Index, Key)
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.cBrand600
                                                .withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(
                                              5,
                                            ),
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
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Padding(
                                            padding: EdgeInsets.only(
                                              right: hasActions
                                                  ? 110
                                                  : 80, // 패딩 증가
                                            ),
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
                                            Icon(
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
                                    const SizedBox(height: 8),
                                    // 메인 콘텐츠
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            parent.front.replaceAll('\n', ' '),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: isDark
                                                  ? Colors.white
                                                  : AppColors.cSlate900,
                                            ),
                                          ),
                                        ),
                                        const Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 10,
                                          ),
                                          child: Text(
                                            '|',
                                            style: TextStyle(
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            parent.back.replaceAll('\n', ' '),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: isDark
                                                  ? AppColors.cSlate300
                                                  : AppColors.cSlate600,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // 상단 플로팅 레이어 (액션 버튼 전용)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (hasActions) ...[...actions!],
                        ],
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
}

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
  });

  @override
  Widget build(BuildContext context) {
    bool hasActions = actions != null && actions!.isNotEmpty;

    return Transform.scale(
      scale: scale,
      child: Opacity(
        opacity: opacity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          child: Row(
            children: [
              CardListUtils.buildDepthSpacers(card.groupDepth),
              if (isParent) CardListUtils.buildDepthSpacers(1),
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // 1. 기본 배경 및 텍스트 레이아웃
                    Material(
                      color: (card.isFlagged
                          ? (isDark
                                ? const Color(0xFF383000)
                                : const Color(0xFFFFFDE7))
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
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
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // 상단 정보 (Index, Key)
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.cBrand600.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(5),
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
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        right: hasActions ? 90 : 45, // 최적화된 패딩
                                      ), // 버튼 공간 확보
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
                                  // 액션이 없을 때 보여줄 작은 상태 아이콘들 (Jump Dialog용)
                                  if (!hasActions) ...[
                                    if (card.remark.isNotEmpty)
                                      Icon(
                                        Icons.history_edu_rounded,
                                        size: 16,
                                        color: isDark
                                            ? AppColors.cBrand600
                                            : AppColors.cBrand600,
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
                              const SizedBox(height: 10),
                              // 메인 콘텐츠 (Front | Back)
                              Row(
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
                                        color: isDark
                                            ? Colors.white
                                            : AppColors.cSlate900,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Text(
                                      '|',
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white24
                                            : AppColors.cSlate300,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      card.back.replaceAll('\n', ' '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isDark
                                            ? AppColors.cSlate300
                                            : AppColors.cSlate600,
                                        fontWeight: FontWeight.w500,
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
                    // 2. 둥둥 떠 있는 액션 버튼 레이어
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
}

class CardSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool isDark;

  const CardSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
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
}
