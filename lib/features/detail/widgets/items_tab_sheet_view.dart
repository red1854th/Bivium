import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:bivium/models/flashcard.dart';
import 'package:bivium/core/theme.dart';
import 'package:bivium/features/detail/widgets/sheet_cell.dart';

class ItemsTabSheetView extends StatelessWidget {
  final List<dynamic> displayItems;
  final List<Flashcard> allCards;
  final bool isDark;
  final String? editingCellId;
  final Function(Flashcard, int, String, String) onUpdateCell;
  final Function(String?) onStartEditing;
  final VoidCallback onRefresh;

  const ItemsTabSheetView({
    super.key,
    required this.displayItems,
    required this.allCards,
    required this.isDark,
    required this.editingCellId,
    required this.onUpdateCell,
    required this.onStartEditing,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (displayItems.isEmpty) {
      return Center(child: Text("no_search_results".tr()));
    }

    final borderColor = isDark ? AppColors.cDarkBorder : AppColors.cSlate200;
    final headerColor = isDark ? AppColors.cDarkSurface : AppColors.cSlate100;

    const double rowNumWidth = 44.0;
    const double keyWidth = 100.0;
    const double frontWidth = 240.0;
    const double backWidth = 240.0;
    const double remarkWidth = 160.0;
    const double totalWidth =
        rowNumWidth + keyWidth + frontWidth + backWidth + remarkWidth;

    return Container(
      margin: const EdgeInsets.only(top: 8, left: 16, right: 16, bottom: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cDarkBg.withValues(alpha: 0.5) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: totalWidth,
          child: Column(
            children: [
              // 헤더
              Container(
                height: 36,
                color: headerColor,
                child: Row(
                  children: [
                    _buildHeaderCell('#', rowNumWidth, isDark),
                    _buildHeaderCell('Key', keyWidth, isDark),
                    _buildHeaderCell("source_label".tr(), frontWidth, isDark),
                    _buildHeaderCell("target_label".tr(), backWidth, isDark),
                    _buildHeaderCell(
                      "remark_col_label".tr(),
                      remarkWidth,
                      isDark,
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: borderColor),
              // 바디
              Expanded(
                child: ListView.separated(
                  itemCount: displayItems.length,
                  separatorBuilder: (context, index) =>
                      Divider(height: 1, color: borderColor),
                  itemBuilder: (context, index) {
                    final item = displayItems[index];
                    final bool isEven = index % 2 == 0;
                    final rowColor = isEven
                        ? Colors.transparent
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.02)
                              : Colors.black.withValues(alpha: 0.01));

                    if (item is Map && item['type'] == 'group_header') {
                      final Flashcard parent = item['parent'];
                      final int originalIdx = allCards.indexOf(parent);
                      return _buildFolderRow(
                        parent,
                        originalIdx,
                        rowNumWidth,
                        keyWidth,
                        frontWidth,
                        backWidth,
                        remarkWidth,
                        borderColor,
                        isDark,
                      );
                    }

                    final Flashcard card = item as Flashcard;
                    final int originalIdx = allCards.indexOf(card);

                    return Container(
                      height: 44,
                      color: rowColor,
                      child: Row(
                        children: [
                          _buildDataCell(
                            '${originalIdx + 1}',
                            rowNumWidth,
                            isDark,
                            isNum: true,
                            borderColor: borderColor,
                          ),
                          _buildEditableCell(
                            card.key,
                            keyWidth,
                            isDark,
                            borderColor,
                            onChanged: (val) =>
                                onUpdateCell(card, originalIdx, 'key', val),
                            isMonospace: true,
                            cellId: '${originalIdx}_key',
                          ),
                          _buildEditableCell(
                            card.front,
                            frontWidth,
                            isDark,
                            borderColor,
                            onChanged: (val) =>
                                onUpdateCell(card, originalIdx, 'front', val),
                            cellId: '${originalIdx}_front',
                          ),
                          _buildEditableCell(
                            card.back,
                            backWidth,
                            isDark,
                            borderColor,
                            onChanged: (val) =>
                                onUpdateCell(card, originalIdx, 'back', val),
                            cellId: '${originalIdx}_back',
                          ),
                          _buildEditableCell(
                            card.remark,
                            remarkWidth,
                            isDark,
                            borderColor,
                            onChanged: (val) =>
                                onUpdateCell(card, originalIdx, 'remark', val),
                            isSmall: true,
                            cellId: '${originalIdx}_remark',
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFolderRow(
    Flashcard parent,
    int originalIdx,
    double rowNumWidth,
    double keyWidth,
    double frontWidth,
    double backWidth,
    double remarkWidth,
    Color borderColor,
    bool isDark,
  ) {
    return Container(
      height: 44,
      color: isDark
          ? AppColors.cBrand600.withValues(alpha: 0.15)
          : AppColors.cBrand600.withValues(alpha: 0.1),
      child: Row(
        children: [
          Container(
            width: rowNumWidth,
            height: 44,
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: borderColor, width: 0.5)),
            ),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    '${originalIdx + 1}',
                    style: TextStyle(
                      color: isDark ? Colors.white24 : AppColors.cSlate300,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Positioned(
                  right: 4,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: InkWell(
                      onTap: () {
                        parent.isCollapsed = !parent.isCollapsed;
                        onRefresh();
                      },
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppColors.cBrand600,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(2),
                          color: isDark ? AppColors.cDarkSurface : Colors.white,
                        ),
                        child: Icon(
                          parent.isCollapsed ? Icons.add : Icons.remove,
                          size: 10,
                          color: AppColors.cBrand600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildEditableCell(
            parent.key,
            keyWidth,
            isDark,
            borderColor,
            onChanged: (val) => onUpdateCell(parent, originalIdx, 'key', val),
            isMonospace: true,
            isBold: true,
            cellId: '${originalIdx}_key',
          ),
          _buildEditableCell(
            parent.front,
            frontWidth,
            isDark,
            borderColor,
            onChanged: (val) => onUpdateCell(parent, originalIdx, 'front', val),
            isBold: true,
            cellId: '${originalIdx}_front',
          ),
          _buildEditableCell(
            parent.back,
            backWidth,
            isDark,
            borderColor,
            onChanged: (val) => onUpdateCell(parent, originalIdx, 'back', val),
            isBold: true,
            cellId: '${originalIdx}_back',
          ),
          _buildEditableCell(
            parent.remark,
            remarkWidth,
            isDark,
            borderColor,
            onChanged: (val) =>
                onUpdateCell(parent, originalIdx, 'remark', val),
            isSmall: true,
            isBold: true,
            cellId: '${originalIdx}_remark',
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String label, double width, bool isDark) {
    return Container(
      width: width,
      height: 36,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: isDark ? AppColors.cDarkBorder : AppColors.cSlate200,
            width: 0.5,
          ),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isDark ? Colors.white70 : AppColors.cSlate700,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildDataCell(
    String value,
    double width,
    bool isDark, {
    bool isNum = false,
    required Color borderColor,
  }) {
    return Container(
      width: width,
      height: 44,
      alignment: isNum ? Alignment.center : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: borderColor, width: 0.5)),
      ),
      child: Text(
        value,
        style: TextStyle(
          color: isDark
              ? (isNum ? Colors.white38 : Colors.white70)
              : (isNum ? AppColors.cSlate400 : AppColors.cSlate700),
          fontSize: isNum ? 10 : 12,
          fontWeight: isNum ? FontWeight.w600 : FontWeight.normal,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildEditableCell(
    String value,
    double width,
    bool isDark,
    Color borderColor, {
    required ValueChanged<String> onChanged,
    bool isMonospace = false,
    bool isSmall = false,
    bool isBold = false,
    required String cellId,
  }) {
    return Container(
      width: width,
      height: 44,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: borderColor, width: 0.5)),
      ),
      child: SheetCell(
        value: value,
        isDark: isDark,
        onChanged: onChanged,
        isMonospace: isMonospace,
        isSmall: isSmall,
        isBold: isBold,
        width: width,
        cellId: cellId,
        isEditing: editingCellId == cellId,
        onStartEditing: onStartEditing,
      ),
    );
  }
}
