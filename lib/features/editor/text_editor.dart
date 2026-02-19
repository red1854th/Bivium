import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:re_editor/re_editor.dart';
import 'highlight_rules.dart';
import 'package:bivium/core/theme.dart';

class TextEditor extends StatefulWidget {
  final String initialContent;
  final ValueChanged<String> onChanged;
  final double fontSize;
  final double lineHeight;
  final String fontFamily;

  const TextEditor({
    super.key,
    required this.initialContent,
    required this.onChanged,
    required this.fontSize,
    required this.lineHeight,
    required this.fontFamily,
  });

  @override
  State<TextEditor> createState() => _TextEditorState();
}

class _TextEditorState extends State<TextEditor> {
  late CodeLineEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  late final SelectionToolbarController _toolbarController;

  static const _shareChannel = MethodChannel('com.bivium.app/share');

  @override
  void initState() {
    super.initState();
    _controller = CodeLineEditingController();
    _controller.text = widget.initialContent;

    _toolbarController = MobileSelectionToolbarController(
      builder: (context, controller) {
        return [
          ToolbarMenuItem(title: 'copy'.tr(), onTap: () => controller.copy()),
          ToolbarMenuItem(title: 'cut'.tr(), onTap: () => controller.cut()),
          ToolbarMenuItem(title: 'paste'.tr(), onTap: () => controller.paste()),
          ToolbarMenuItem(
            title: 'select_all'.tr(),
            onTap: () => controller.selectAll(),
          ),
          ToolbarMenuItem(
            title: 'share'.tr(),
            onTap: () {
              final selection = controller.selection;
              if (!selection.isCollapsed) {
                final text = controller.text.substring(
                  selection.start.offset,
                  selection.end.offset,
                );
                if (text.isNotEmpty) _shareText(text);
              }
            },
          ),
        ];
      },
    );

    _controller.addListener(() => widget.onChanged(_controller.text));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _shareText(String text) async {
    if (kIsWeb) return;
    try {
      await _shareChannel.invokeMethod('shareText', {'text': text});
    } catch (e) {
      debugPrint('Share error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) =>
          _toolbarController.hide(context),
      child: Container(
        transform: Matrix4.translationValues(-10, 0, 0),
        // Shortcuts 위젯을 사용하여 화살표 키 이동 문제를 해결합니다.
        child: Shortcuts(
          shortcuts: <ShortcutActivator, Intent>{
            LogicalKeySet(LogicalKeyboardKey.arrowUp):
                const DirectionalFocusIntent(TraversalDirection.up),
            LogicalKeySet(LogicalKeyboardKey.arrowDown):
                const DirectionalFocusIntent(TraversalDirection.down),
            LogicalKeySet(LogicalKeyboardKey.arrowLeft):
                const DirectionalFocusIntent(TraversalDirection.left),
            LogicalKeySet(LogicalKeyboardKey.arrowRight):
                const DirectionalFocusIntent(TraversalDirection.right),
          },
          child: CodeEditor(
            controller: _controller,
            focusNode: _focusNode,
            autofocus: false,
            wordWrap: true,
            toolbarController: _toolbarController,
            scrollbarBuilder: (context, child, details) {
              return RawScrollbar(
                controller: details.controller,
                thickness: 3.0,
                radius: const Radius.circular(2),
                thumbColor: isDark
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.1),
                fadeDuration: const Duration(milliseconds: 300),
                child: child,
              );
            },
            indicatorBuilder:
                (context, editingController, chunkController, notifier) {
                  return Container(
                    constraints: const BoxConstraints(minWidth: 50),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 8),
                    child: DefaultCodeLineNumber(
                      controller: editingController,
                      notifier: notifier,
                      textStyle: TextStyle(
                        color: isDark ? Colors.white38 : Colors.black38,
                        fontSize: widget.fontSize,
                        fontFamily: widget.fontFamily,
                        height: widget.lineHeight,
                      ),
                      focusedTextStyle: TextStyle(
                        color: AppColors.cBrand600,
                        fontSize: widget.fontSize,
                        fontFamily: widget.fontFamily,
                        fontWeight: FontWeight.bold,
                        height: widget.lineHeight,
                      ),
                    ),
                  );
                },
            style: CodeEditorStyle(
              fontSize: widget.fontSize,
              fontFamily: widget.fontFamily,
              codeTheme: CodeHighlightTheme(
                languages: {
                  'plaintext': CodeHighlightThemeMode(
                    mode: HighlightRules.buildMode(),
                  ),
                },
                theme: isDark ? _darkCodeTheme() : _lightCodeTheme(),
              ),
              backgroundColor: Colors.transparent,
            ),
          ),
        ),
      ),
    );
  }

  Map<String, TextStyle> _darkCodeTheme() => {
    'root': TextStyle(
      color: Colors.white,
      height: widget.lineHeight,
      fontSize: widget.fontSize,
    ),
    ...HighlightRules.gameTagPatterns,
  };

  Map<String, TextStyle> _lightCodeTheme() => {
    'root': TextStyle(
      color: Colors.black87,
      height: widget.lineHeight,
      fontSize: widget.fontSize,
    ),
    ...HighlightRules.gameTagPatterns,
  };
}
