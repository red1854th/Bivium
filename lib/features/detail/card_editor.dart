import 'package:flutter/material.dart';
import 'package:bivium/models/flashcard.dart';
import 'package:bivium/services/google_drive_service.dart';
import 'package:bivium/core/theme.dart';
import 'package:bivium/features/editor/text_editor.dart';
import 'package:bivium/features/detail/remark_page.dart';
import 'package:bivium/features/detail/remark_setting_page.dart';
import 'package:bivium/features/home/widgets/editor_settings_panel.dart';

class CardEditor extends StatefulWidget {
  final Flashcard card;
  final int cardIndex;
  final FlashcardSet setInfo;
  final GoogleDriveService driveService;
  final bool isVertical;
  final EditorSettings settings;
  final VoidCallback onLayoutToggle;
  final VoidCallback onSettingsToggle;
  final VoidCallback? onToolbarCustomize;
  final VoidCallback? onSetUpdated;
  final void Function({
    ZebraHighlightController? controller,
    UndoHistoryController? undoController,
    required bool isFront,
  })?
  onFocusChanged;

  const CardEditor({
    super.key,
    required this.card,
    required this.cardIndex,
    required this.setInfo,
    required this.driveService,
    required this.isVertical,
    required this.settings,
    required this.onLayoutToggle,
    required this.onSettingsToggle,
    this.onToolbarCustomize,
    this.onSetUpdated,
    this.onFocusChanged,
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

  bool _isToolbarExpanded = false;
  late ZebraHighlightController _activeController;
  late UndoHistoryController _activeUndoController;
  bool _isFrontActive = true;

  @override
  void initState() {
    super.initState();
    _frontController = ZebraHighlightController()..text = widget.card.front;
    _backController = ZebraHighlightController()..text = widget.card.back;

    _activeController = _frontController;
    _activeUndoController = _frontUndoController;

    _frontFocus.addListener(() {
      if (_frontFocus.hasFocus) {
        setState(() {
          _activeController = _frontController;
          _activeUndoController = _frontUndoController;
          _isFrontActive = true;
        });
        _notifyParent();
      }
    });
    _backFocus.addListener(() {
      if (_backFocus.hasFocus) {
        setState(() {
          _activeController = _backController;
          _activeUndoController = _backUndoController;
          _isFrontActive = false;
        });
        _notifyParent();
      }
    });

    _frontUndoController.addListener(() {
      setState(() {});
      if (_frontFocus.hasFocus) _notifyParent();
    });
    _backUndoController.addListener(() {
      setState(() {});
      if (_backFocus.hasFocus) _notifyParent();
    });
  }

  void _notifyParent() {
    widget.onFocusChanged?.call(
      controller: _activeController,
      undoController: _activeUndoController,
      isFront: _isFrontActive,
    );
  }

  @override
  void dispose() {
    _frontUndoController.dispose();
    _backUndoController.dispose();
    _frontController.dispose();
    _backController.dispose();
    _frontFocus.dispose();
    _backFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 5, 10, 5),
      decoration: BoxDecoration(
        color: widget.card.isFlagged
            ? (isDark
                  ? const Color(0xFFFFFF00).withAlpha(25)
                  : const Color(0xFFFFF9C4))
            : (isDark ? AppColors.cDarkBg : AppColors.cBg),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isDark ? AppColors.cDarkBorder : AppColors.cSlate200,
        ),
      ),
      child: Flex(
        direction: widget.isVertical ? Axis.vertical : Axis.horizontal,
        children: [
          Expanded(
            child: TextEditor(
              controller: _frontController,
              focusNode: _frontFocus,
              undoController: _frontUndoController,
              onChanged: (v) => widget.card.front = v,
              fontSize: widget.settings.fontSize,
              lineHeight: widget.settings.lineHeight,
              fontFamily: widget.settings.fontFamily,
            ),
          ),
          _buildMiddleToolbar(isDark),
          Expanded(
            child: TextEditor(
              controller: _backController,
              focusNode: _backFocus,
              undoController: _backUndoController,
              onChanged: (v) => widget.card.back = v,
              fontSize: widget.settings.fontSize,
              lineHeight: widget.settings.lineHeight,
              fontFamily: widget.settings.fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiddleToolbar(bool isDark) {
    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    if (isKeyboardOpen) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          // 터치가 잘 되도록 보이지 않는 여백 확보
          padding: EdgeInsets.symmetric(
            vertical: widget.isVertical ? 10 : 0,
            horizontal: widget.isVertical ? 0 : 10,
          ),
          child: Container(
            width: widget.isVertical ? double.infinity : 1,
            height: widget.isVertical ? 1 : double.infinity,
            color: isDark ? Colors.white10 : Colors.black12,
          ),
        ),
      );
    }

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: Container(
            width: widget.isVertical ? double.infinity : 1,
            height: widget.isVertical ? 1 : double.infinity,
            color: isDark ? Colors.white10 : Colors.black12,
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.fastOutSlowIn,
          width: _isToolbarExpanded
              ? MediaQuery.of(context).size.width * 0.8
              : 80, // 접혔을 때 터치 너비 확장
          height: _isToolbarExpanded ? 44 : 32, // 접혔을 때 터치 높이 확장
          decoration: BoxDecoration(
            color: _isToolbarExpanded
                ? (isDark ? AppColors.cDarkSurface : Colors.white)
                : Colors.transparent, // 접혔을 때는 배경 투명하게 (내부 캡슐만 보임)
            borderRadius: BorderRadius.circular(_isToolbarExpanded ? 22 : 16),
            boxShadow: _isToolbarExpanded
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
            border: _isToolbarExpanded
                ? Border.all(
                    color: isDark
                        ? Colors.white10
                        : Colors.black.withValues(alpha: 0.05),
                  )
                : null,
          ),
          child: InkWell(
            onTap: () {
              FocusScope.of(context).unfocus();
              if (!_isToolbarExpanded) {
                setState(() => _isToolbarExpanded = true);
              }
            },
            borderRadius: BorderRadius.circular(_isToolbarExpanded ? 22 : 16),
            child: _isToolbarExpanded
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _toolbarAction(
                        icon: Icons.history_edu_rounded,
                        color: widget.card.remark.isNotEmpty
                            ? AppColors.cBrand600
                            : (isDark ? AppColors.cSlate400 : Colors.grey),
                        onTap: () {
                          FocusScope.of(context).unfocus();
                          _handleRemarkAction();
                        },
                      ),
                      _toolbarAction(
                        icon: widget.card.isFlagged
                            ? Icons.flag
                            : Icons.flag_outlined,
                        color: widget.card.isFlagged
                            ? Colors.orange
                            : (isDark ? AppColors.cSlate400 : Colors.grey),
                        onTap: () {
                          FocusScope.of(context).unfocus();
                          setState(
                            () =>
                                widget.card.isFlagged = !widget.card.isFlagged,
                          );
                        },
                      ),
                      _toolbarAction(
                        icon: Icons.view_agenda_rounded,
                        color: isDark ? AppColors.cSlate400 : Colors.grey,
                        onTap: () {
                          FocusScope.of(context).unfocus();
                          widget.onLayoutToggle();
                        },
                        isVerticalIcon: true,
                      ),
                      _toolbarAction(
                        icon: Icons.more_vert_rounded,
                        color: isDark ? AppColors.cSlate400 : Colors.grey,
                        onTap: () {
                          FocusScope.of(context).unfocus();
                          setState(() => _isToolbarExpanded = false);
                          widget.onSettingsToggle();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        color: isDark
                            ? AppColors.cSlate600
                            : Colors.grey.withValues(alpha: 0.5),
                        onPressed: () =>
                            setState(() => _isToolbarExpanded = false),
                      ),
                    ],
                  )
                : Center(
                    child: Container(
                      width: 50,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _toolbarAction({
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
    bool isVerticalIcon = false,
  }) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
      icon: isVerticalIcon
          ? RotatedBox(
              quarterTurns: widget.isVertical ? 0 : 1,
              child: Icon(icon, size: 20, color: color),
            )
          : Icon(icon, size: 20, color: color),
    );
  }

  Future<void> _handleRemarkAction() async {
    if (widget.setInfo.remarkColIdx == -1) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RemarkSettingPage(
            service: widget.driveService,
            spreadsheetId: widget.setInfo.sheetId,
            onConfirm: (idx) {
              setState(() {
                widget.setInfo.remarkColIdx = idx;
              });
              widget.onSetUpdated?.call();
            },
          ),
        ),
      );
      if (!mounted) return;
      if (widget.setInfo.remarkColIdx == -1) return;
    }

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
    if (!mounted) return;
    if (res != null) {
      setState(() => widget.card.remark = res);
    }
  }
}
