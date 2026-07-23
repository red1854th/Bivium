import 'dart:async';
import 'package:flutter/material.dart';
import 'package:bivium/models/flashcard.dart';
import 'package:bivium/models/glossary_item.dart';
import 'package:bivium/services/google_drive_service.dart';
import 'package:bivium/core/theme.dart';
import 'package:bivium/core/responsive.dart';
import 'package:bivium/features/editor/text_editor.dart';
import 'package:bivium/features/detail/remark_page.dart';
import 'package:bivium/features/detail/remark_setting_page.dart';
import 'package:bivium/features/home/widgets/editor_settings_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bivium/models/substitution.dart';
import 'package:easy_localization/easy_localization.dart';

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
  List<Substitution> _allSubstitutions = [];
  List<GlossaryItem> _glossary = [];
  String? _glossaryFeedback;
  Timer? _feedbackTimer;

  @override
  void initState() {
    super.initState();
    _frontController = ZebraHighlightController()..text = widget.card.front;
    _backController = ZebraHighlightController()..text = widget.card.back;

    _loadSubstitutions();

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

  Future<void> _loadSubstitutions() async {
    final prefs = await SharedPreferences.getInstance();
    final globalJson = prefs.getString('global_substitutions') ?? '[]';
    final globalSubs = Substitution.deserializeList(globalJson);

    final projectJson = widget.setInfo.metadata?['substitutions'] ?? '[]';
    final projectSubs = Substitution.deserializeList(projectJson);

    final glossaryJson = widget.setInfo.metadata?['glossary'] ?? '[]';
    final glossaryItems = GlossaryItem.deserializeList(glossaryJson);

    setState(() {
      _allSubstitutions = [...globalSubs, ...projectSubs];
      _glossary = glossaryItems;
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
    _feedbackTimer?.cancel();
    super.dispose();
  }

  void _showGlossaryFeedback(GlossaryItem item) {
    _feedbackTimer?.cancel();
    setState(() {
      _glossaryFeedback = "${item.source} → ${item.targets.join(', ')}";
    });
    _feedbackTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _glossaryFeedback = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isDesktop = Responsive.isDesktop(context);
    final effectiveIsVertical = isDesktop ? false : widget.isVertical;

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
        direction: effectiveIsVertical ? Axis.vertical : Axis.horizontal,
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
              substitutions: _allSubstitutions,
              glossary: _glossary,
              onGlossaryLongPress: _showGlossaryFeedback,
            ),
          ),
          _buildMiddleToolbar(isDark, isDesktop),
          Expanded(
            child: TextEditor(
              controller: _backController,
              focusNode: _backFocus,
              undoController: _backUndoController,
              onChanged: (v) => widget.card.back = v,
              fontSize: widget.settings.fontSize,
              lineHeight: widget.settings.lineHeight,
              fontFamily: widget.settings.fontFamily,
              substitutions: _allSubstitutions,
              glossary: _glossary,
              onGlossaryLongPress: _showGlossaryFeedback,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiddleToolbar(bool isDark, bool isDesktop) {
    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    if (isKeyboardOpen && !isDesktop) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          // 터치가 잘 되도록 보이지 않는 여백 확보
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Container(
            width: double.infinity,
            height: 1,
            color: isDark ? Colors.white10 : Colors.black12,
          ),
        ),
      );
    }

    final bool isEffectivelyExpanded =
        _isToolbarExpanded || _glossaryFeedback != null || isDesktop;

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: Container(
            width: double.infinity,
            height: 1,
            color: isDark ? Colors.white10 : Colors.black12,
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.fastOutSlowIn,
          width: isDesktop
              ? 44
              : (isEffectivelyExpanded
                    ? MediaQuery.of(context).size.width * 0.8
                    : 80),
          height: isDesktop ? 220 : (isEffectivelyExpanded ? 44 : 32),
          decoration: BoxDecoration(
            color: isEffectivelyExpanded
                ? (isDark ? AppColors.cDarkSurface : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(
              isDesktop ? 22 : (isEffectivelyExpanded ? 22 : 16),
            ),
            boxShadow: isEffectivelyExpanded
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
            border: isEffectivelyExpanded
                ? Border.all(
                    color: isDark
                        ? Colors.white10
                        : Colors.black.withValues(alpha: 0.05),
                  )
                : null,
          ),
          child: InkWell(
            onTap: isDesktop
                ? null
                : () {
                    FocusScope.of(context).unfocus();
                    if (!_isToolbarExpanded) {
                      setState(() => _isToolbarExpanded = true);
                    }
                  },
            borderRadius: BorderRadius.circular(
              isEffectivelyExpanded ? 22 : 16,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(
                      begin: 0.95,
                      end: 1.0,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: _glossaryFeedback != null
                  ? Center(
                      key: const ValueKey('glossary_feedback'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          _glossaryFeedback!,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.cBrand600.withAlpha(200)
                                : AppColors.cBrand600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                  : (isEffectivelyExpanded || isDesktop)
                  ? Flex(
                      direction: isDesktop ? Axis.vertical : Axis.horizontal,
                      key: const ValueKey('toolbar_actions'),
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
                          tooltip: "remark".tr(),
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
                              () => widget.card.isFlagged =
                                  !widget.card.isFlagged,
                            );
                          },
                          tooltip: "flag".tr(),
                        ),
                        if (!isDesktop)
                          _toolbarAction(
                            icon: Icons.view_agenda_rounded,
                            color: isDark ? AppColors.cSlate400 : Colors.grey,
                            onTap: () {
                              FocusScope.of(context).unfocus();
                              widget.onLayoutToggle();
                            },
                            isVerticalIcon: true,
                            tooltip: "toggle_layout".tr(),
                          ),
                        _toolbarAction(
                          icon: Icons.more_vert_rounded,
                          color: isDark ? AppColors.cSlate400 : Colors.grey,
                          onTap: () {
                            FocusScope.of(context).unfocus();
                            if (!isDesktop) {
                              setState(() => _isToolbarExpanded = false);
                            }
                            widget.onSettingsToggle();
                          },
                          tooltip: "settings".tr(),
                        ),
                        if (!isDesktop)
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
                      key: const ValueKey('collapsed_handle'),
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
        ),
      ],
    );
  }

  Widget _toolbarAction({
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
    bool isVerticalIcon = false,
    String? tooltip,
  }) {
    final button = IconButton(
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
      icon: isVerticalIcon
          ? RotatedBox(
              quarterTurns: widget.isVertical ? 0 : 1,
              child: Icon(icon, size: 20, color: color),
            )
          : Icon(icon, size: 20, color: color),
    );

    if (tooltip != null && Responsive.isDesktop(context)) {
      return Tooltip(message: tooltip, child: button);
    }
    return button;
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
