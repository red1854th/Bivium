import 'package:flutter/material.dart';
import 'package:bivium/models/toolbar_item.dart';
import 'package:bivium/core/theme.dart';

class ToolbarCustomizePage extends StatefulWidget {
  final List<ToolbarItem> items;
  final void Function(List<ToolbarItem>) onSave;

  const ToolbarCustomizePage({
    super.key,
    required this.items,
    required this.onSave,
  });

  @override
  State<ToolbarCustomizePage> createState() => _ToolbarCustomizePageState();
}

class _ToolbarCustomizePageState extends State<ToolbarCustomizePage> {
  late List<ToolbarItem> _items;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.items);
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
    });
  }

  void _toggleVisibility(int index) {
    setState(() {
      _items[index] = _items[index].copyWith(
        isVisible: !_items[index].isVisible,
      );
    });
  }

  void _save() {
    widget.onSave(_items);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.cDarkBg : AppColors.cSlate50,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '툴바 커스텀',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.cSlate100 : AppColors.cSlate800,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(
              '저장',
              style: TextStyle(
                color: AppColors.cBrand600,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 미리보기
          _buildPreview(isDark),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Row(
              children: [
                Text(
                  '순서 변경 및 표시 설정',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.cSlate400 : AppColors.cSlate500,
                    letterSpacing: 0.3,
                  ),
                ),
                const Spacer(),
                Text(
                  '드래그하여 순서 변경',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.cSlate600 : AppColors.cSlate400,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: _items.length,
              onReorder: _onReorder,
              proxyDecorator: (child, index, animation) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, ch) {
                    return Material(
                      elevation: 8 * animation.value,
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      child: child,
                    );
                  },
                );
              },
              itemBuilder: (context, index) {
                final item = _items[index];
                return _buildItemTile(item, index, isDark);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(bool isDark) {
    final visible = _items.where((e) => e.isVisible).toList();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black12,
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
            child: Text(
              '미리보기',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.cSlate500 : AppColors.cSlate400,
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: visible.isEmpty
                ? Center(
                    child: Text(
                      '표시할 버튼이 없습니다',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.cSlate600
                            : AppColors.cSlate400,
                      ),
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: visible.length,
                    itemBuilder: (context, i) {
                      final it = visible[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () {},
                          icon: Icon(
                            it.icon,
                            size: 20,
                            color: AppColors.cBrand600,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemTile(ToolbarItem item, int index, bool isDark) {
    return Container(
      key: ValueKey(item.type.name),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: item.isVisible ? 0.07 : 0.03)
            : Colors.black.withValues(alpha: item.isVisible ? 0.04 : 0.02),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.isVisible
              ? (isDark ? Colors.white12 : Colors.black12)
              : (isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.05)),
          width: 0.5,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: item.isVisible
                ? AppColors.cBrand600.withValues(alpha: 0.15)
                : (isDark
                      ? Colors.white10
                      : Colors.black.withValues(alpha: 0.06)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            item.icon,
            size: 18,
            color: item.isVisible
                ? AppColors.cBrand600
                : (isDark ? AppColors.cSlate600 : AppColors.cSlate400),
          ),
        ),
        title: Text(
          item.label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: item.isVisible
                ? (isDark ? AppColors.cSlate200 : AppColors.cSlate800)
                : (isDark ? AppColors.cSlate600 : AppColors.cSlate400),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => _toggleVisibility(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 26,
                decoration: BoxDecoration(
                  color: item.isVisible
                      ? AppColors.cBrand600
                      : (isDark ? AppColors.cDarkBorder : AppColors.cSlate200),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 200),
                  alignment: item.isVisible
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.all(3),
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.drag_handle_rounded,
              color: isDark ? AppColors.cSlate600 : AppColors.cSlate300,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
