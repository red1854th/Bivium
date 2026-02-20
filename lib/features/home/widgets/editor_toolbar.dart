import 'package:flutter/material.dart';
import 'package:bivium/core/theme.dart';

class EditorToolbar extends StatefulWidget {
  final TextEditingController activeController;
  final UndoHistoryController undoController;
  final VoidCallback onHideKeyboard;
  final Function(String) onUpdateCard;

  const EditorToolbar({
    super.key,
    required this.activeController,
    required this.undoController,
    required this.onHideKeyboard,
    required this.onUpdateCard,
  });

  @override
  State<EditorToolbar> createState() => _EditorToolbarState();
}

class _EditorToolbarState extends State<EditorToolbar> {
  // 각 텍스트 상태에 대응하는 커서 위치를 저장하는 스택
  final List<int> _offsetStack = [];
  String _lastText = "";

  @override
  void initState() {
    super.initState();
    _lastText = widget.activeController.text;
    // 초기 위치 저장
    _offsetStack.add(widget.activeController.selection.baseOffset);
    widget.activeController.addListener(_recordCursorState);
  }

  @override
  void dispose() {
    widget.activeController.removeListener(_recordCursorState);
    super.dispose();
  }

  // 글자가 입력되거나 지워진 '직후'의 커서 위치를 기록
  void _recordCursorState() {
    final currentText = widget.activeController.text;
    final currentOffset = widget.activeController.selection.baseOffset;

    // 텍스트가 실제로 변했을 때만 위치를 스택에 기록
    if (currentText != _lastText && currentOffset != -1) {
      _offsetStack.add(currentOffset);
      _lastText = currentText;

      // 메모리 최적화
      if (_offsetStack.length > 100) _offsetStack.removeAt(0);
    }
  }

  void _handleUndo() {
    if (!widget.undoController.value.canUndo) return;

    // 1. Undo 실행 전 현재 상태(지워질 글자가 있는 상태)의 기록 제거
    if (_offsetStack.isNotEmpty) _offsetStack.removeLast();

    // 2. Undo 실행
    widget.undoController.undo();

    final String newText = widget.activeController.text;
    _lastText = newText;

    // 3. 스택에서 직전 상태일 때 기록된 위치 추출
    int targetOffset = _offsetStack.isNotEmpty
        ? _offsetStack.last
        : newText.length;

    // 4. 즉시 적용하여 커서 튐 방지
    widget.activeController.value = widget.activeController.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(
        offset: targetOffset.clamp(0, newText.length),
      ),
    );

    widget.onUpdateCard(newText);
  }

  void _insertTag(String tag) {
    final selection = widget.activeController.selection;
    final text = widget.activeController.text;
    final newText = text.replaceRange(selection.start, selection.end, tag);

    widget.activeController.value = widget.activeController.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: selection.start + tag.length),
    );
    widget.onUpdateCard(newText);
  }

  void _moveCursor(int offset) {
    final newOffset = widget.activeController.selection.extentOffset + offset;
    if (newOffset >= 0 && newOffset <= widget.activeController.text.length) {
      widget.activeController.selection = TextSelection.collapsed(
        offset: newOffset,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      elevation: 10,
      child: Container(
        height: 45,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF8F8F8),
        child: Row(
          children: [
            _toolIcon(Icons.add_box_outlined, () => _insertTag("[ ]")),
            ValueListenableBuilder<UndoHistoryValue>(
              valueListenable: widget.undoController,
              builder: (context, value, _) {
                return Row(
                  children: [
                    _toolIcon(
                      Icons.undo_rounded,
                      value.canUndo ? _handleUndo : null,
                    ),
                    _toolIcon(
                      Icons.redo_rounded,
                      value.canRedo ? widget.undoController.redo : null,
                    ),
                  ],
                );
              },
            ),
            const Spacer(),
            _toolIcon(Icons.arrow_back_ios_new_rounded, () => _moveCursor(-1)),
            _toolIcon(Icons.arrow_forward_ios_rounded, () => _moveCursor(1)),
            const VerticalDivider(width: 20, indent: 12, endIndent: 12),
            _toolIcon(Icons.keyboard_hide_rounded, widget.onHideKeyboard),
          ],
        ),
      ),
    );
  }

  Widget _toolIcon(IconData icon, VoidCallback? onTap) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(
        icon,
        size: 22,
        color: onTap == null ? Colors.grey.withAlpha(128) : AppColors.cBrand600,
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}
