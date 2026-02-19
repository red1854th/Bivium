import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bivium/models/flashcard.dart';
import 'package:bivium/services/google_drive_service.dart';
import 'package:bivium/features/detail/remark_page.dart';
import 'package:bivium/core/theme.dart';
import 'package:bivium/features/editor/text_editor.dart';
import 'package:bivium/features/home/widgets/editor_settings_panel.dart';

class CardEditor extends StatefulWidget {
  final Flashcard card;
  final int cardIndex;
  final FlashcardSet setInfo;
  final GoogleDriveService driveService;
  final Function(bool) onSettingsToggle;

  const CardEditor({
    super.key,
    required this.card,
    required this.cardIndex,
    required this.setInfo,
    required this.driveService,
    required this.onSettingsToggle,
  });

  @override
  State<CardEditor> createState() => _CardEditorState();
}

class _CardEditorState extends State<CardEditor> with WidgetsBindingObserver {
  late ZebraHighlightController _frontController;
  late ZebraHighlightController _backController;
  final FocusNode _frontFocus = FocusNode();
  final FocusNode _backFocus = FocusNode();

  final UndoHistoryController _frontUndoController = UndoHistoryController();
  final UndoHistoryController _backUndoController = UndoHistoryController();

  OverlayEntry? _overlayEntry;
  bool _isKeyboardVisible = false;
  bool _isSettingsOpen = false;
  bool _isVertical = true;
  EditorSettings _settings = EditorSettings(
    fontSize: 19.0,
    lineHeight: 1.4,
    fontFamily: 'Pretendard',
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _frontController = ZebraHighlightController()..text = widget.card.front;
    _backController = ZebraHighlightController()..text = widget.card.back;

    _frontUndoController.addListener(_updateToolbar);
    _backUndoController.addListener(_updateToolbar);
    _loadPreferences();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _removeToolbar();
    _frontUndoController.dispose();
    _backUndoController.dispose();
    _frontController.dispose();
    _backController.dispose();
    _frontFocus.dispose();
    _backFocus.dispose();
    super.dispose();
  }

  void _updateToolbar() {
    if (_overlayEntry != null) _overlayEntry!.markNeedsBuild();
  }

  @override
  void didChangeMetrics() {
    final bottomInset = WidgetsBinding
        .instance
        .platformDispatcher
        .views
        .first
        .viewInsets
        .bottom;
    final newValue = bottomInset > 0;
    if (_isKeyboardVisible != newValue) {
      _isKeyboardVisible = newValue;
      if (_isKeyboardVisible && (_frontFocus.hasFocus || _backFocus.hasFocus)) {
        _showToolbar();
      } else {
        _removeToolbar();
      }
    }
  }

  void _showToolbar() {
    _removeToolbar();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
        if (keyboardHeight == 0) return const SizedBox.shrink();

        final activeUndo = _frontFocus.hasFocus
            ? _frontUndoController
            : _backUndoController;

        return Positioned(
          bottom: keyboardHeight,
          left: 0,
          right: 0,
          child: Material(
            elevation: 10,
            child: Container(
              height: 45,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF8F8F8),
              child: Row(
                children: [
                  _toolIcon(
                    Icons.add_box_outlined,
                    () => _handleInsertText("[ ]"),
                  ),
                  ValueListenableBuilder(
                    valueListenable: activeUndo,
                    builder: (context, value, _) {
                      return Row(
                        children: [
                          _toolIcon(
                            Icons.undo_rounded,
                            value.canUndo ? () => activeUndo.undo() : null,
                          ),
                          _toolIcon(
                            Icons.redo_rounded,
                            value.canRedo ? () => activeUndo.redo() : null,
                          ),
                        ],
                      );
                    },
                  ),
                  const Spacer(),
                  _toolIcon(
                    Icons.arrow_back_ios_new_rounded,
                    () => _moveCursor(-1),
                  ),
                  _toolIcon(
                    Icons.arrow_forward_ios_rounded,
                    () => _moveCursor(1),
                  ),
                  const VerticalDivider(width: 20, indent: 12, endIndent: 12),
                  _toolIcon(
                    Icons.keyboard_hide_rounded,
                    () => FocusScope.of(context).unfocus(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeToolbar() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _handleInsertText(String text) {
    final controller = _frontFocus.hasFocus
        ? _frontController
        : _backController;
    final selection = controller.selection;

    // 이력을 남기기 위해 value를 직접 교체 (TextField가 포커스된 상태여야 함)
    final newText = controller.text.replaceRange(
      selection.start,
      selection.end,
      text,
    );

    controller.value = controller.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: selection.start + text.length),
    );

    // 수동 변경 후 프런트엔드 반영을 위해 onChanged 호출
    if (_frontFocus.hasFocus) {
      widget.card.front = newText;
    } else {
      widget.card.back = newText;
    }
  }

  void _moveCursor(int offset) {
    final controller = _frontFocus.hasFocus
        ? _frontController
        : _backController;
    final newOffset = controller.selection.extentOffset + offset;
    if (newOffset >= 0 && newOffset <= controller.text.length) {
      controller.selection = TextSelection.collapsed(offset: newOffset);
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _isVertical = prefs.getBool('is_editor_vertical') ?? true;
      _settings = EditorSettings(
        fontSize: prefs.getDouble('editor_font_size') ?? 19.0,
        lineHeight: prefs.getDouble('editor_line_height') ?? 1.4,
        fontFamily: prefs.getString('editor_font_family') ?? 'Pretendard',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(10, 5, 10, 10),
                decoration: BoxDecoration(
                  color: widget.card.isFlagged
                      ? (isDark
                            ? const Color(0xFFFFFF00).withValues(alpha: 0.1)
                            : const Color(0xFFFFF9C4))
                      : (isDark ? AppColors.cDarkBg : AppColors.cBg),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: isDark ? AppColors.cDarkBorder : AppColors.cSlate200,
                  ),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: Flex(
                        direction: _isVertical
                            ? Axis.vertical
                            : Axis.horizontal,
                        children: [
                          Expanded(
                            child: TextEditor(
                              controller: _frontController,
                              focusNode: _frontFocus,
                              undoController: _frontUndoController,
                              onChanged: (v) => widget.card.front = v,
                              fontSize: _settings.fontSize,
                              lineHeight: _settings.lineHeight,
                              fontFamily: _settings.fontFamily,
                            ),
                          ),
                          Container(
                            width: _isVertical ? double.infinity : 1,
                            height: _isVertical ? 1 : double.infinity,
                            color: isDark ? Colors.white10 : Colors.black12,
                          ),
                          Expanded(
                            child: TextEditor(
                              controller: _backController,
                              focusNode: _backFocus,
                              undoController: _backUndoController,
                              onChanged: (v) => widget.card.back = v,
                              fontSize: _settings.fontSize,
                              lineHeight: _settings.lineHeight,
                              fontFamily: _settings.fontFamily,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildBottomToolbar(context),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (_isSettingsOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                setState(() => _isSettingsOpen = false);
                widget.onSettingsToggle(false);
              },
              child: Container(color: Colors.black45),
            ),
          ),
        EditorSettingsPanel(
          isVisible: _isSettingsOpen,
          currentSettings: _settings,
          card: widget.card,
          cardIndex: widget.cardIndex,
          onSettingsChanged: (s) => setState(() => _settings = s),
          onClose: () {
            setState(() => _isSettingsOpen = false);
            widget.onSettingsToggle(false);
          },
        ),
      ],
    );
  }

  Widget _toolIcon(IconData icon, VoidCallback? onTap) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(
        icon,
        size: 22,
        color: onTap == null
            ? Colors.grey.withValues(alpha: 0.5)
            : AppColors.cBrand600,
      ),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildBottomToolbar(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 40,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : Colors.black12,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _iconAction(
            icon: Icons.history_edu_rounded,
            color: widget.card.remark.isNotEmpty
                ? AppColors.cBrand600
                : Colors.grey,
            onTap: () async {
              final res = await Navigator.push<String>(
                context,
                MaterialPageRoute(
                  builder: (_) => RemarkPage(
                    service: widget.driveService,
                    spreadsheetId: widget.setInfo.sheetId,
                    cardIndex: widget.cardIndex,
                    columnIdx: widget.setInfo.remarkColIdx,
                    initialRemark: widget.card.remark,
                    frontText: widget.card.front,
                    backText: widget.card.back,
                    cardKey: widget.card.key,
                  ),
                ),
              );
              if (res != null) setState(() => widget.card.remark = res);
            },
          ),
          _iconAction(
            icon: widget.card.isFlagged ? Icons.flag : Icons.flag_outlined,
            color: widget.card.isFlagged ? Colors.orange : Colors.grey,
            onTap: () =>
                setState(() => widget.card.isFlagged = !widget.card.isFlagged),
          ),
          _iconAction(
            onTap: () => setState(() => _isVertical = !_isVertical),
            child: RotatedBox(
              quarterTurns: _isVertical ? 0 : 1,
              child: const Icon(
                Icons.view_agenda_rounded,
                size: 20,
                color: Colors.grey,
              ),
            ),
          ),
          _iconAction(
            icon: Icons.more_vert_rounded,
            onTap: () {
              setState(() => _isSettingsOpen = true);
              widget.onSettingsToggle(true);
            },
          ),
        ],
      ),
    );
  }

  Widget _iconAction({
    IconData? icon,
    Color color = Colors.grey,
    required VoidCallback onTap,
    Widget? child,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Center(child: child ?? Icon(icon, size: 20, color: color)),
      ),
    );
  }
}
