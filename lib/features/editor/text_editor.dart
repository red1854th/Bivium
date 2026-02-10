import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/plaintext.dart';
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

  // 툴바 제어를 위해 컨트롤러를 상단에 선언합니다.
  late final SelectionToolbarController _toolbarController;

  static const _shareChannel = MethodChannel('com.bivium.app/share');

  @override
  void initState() {
    super.initState();
    _controller = CodeLineEditingController();
    _controller.text = widget.initialContent;

    // 툴바 컨트롤러 초기화
    _toolbarController = MobileSelectionToolbarController(
      builder: (context, controller) {
        return [
          ToolbarMenuItem(title: 'Copy', onTap: () => controller.copy()),
          ToolbarMenuItem(title: 'Cut', onTap: () => controller.cut()),
          ToolbarMenuItem(title: 'Paste', onTap: () => controller.paste()),
          ToolbarMenuItem(
            title: 'Select All',
            onTap: () => controller.selectAll(),
          ),
          ToolbarMenuItem(
            title: 'Share',
            onTap: () {
              final CodeLineSelection selection = controller.selection;
              final int start = selection.start.offset;
              final int end = selection.end.offset;
              if (start != end) {
                final int min = start < end ? start : end;
                final int max = start < end ? end : start;
                final String selectedText = controller.text.substring(min, max);
                if (selectedText.isNotEmpty) {
                  _shareText(selectedText);
                }
              }
            },
          ),
        ];
      },
    );

    _controller.addListener(() {
      widget.onChanged(_controller.text);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _shareText(String text) async {
    try {
      await _shareChannel.invokeMethod('shareText', {'text': text});
    } catch (e) {
      debugPrint('Share error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // PopScope를 사용하여 뒤로 가기 시 툴바를 닫습니다.
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        _toolbarController.hide(context);
      },
      child: Container(
        transform: Matrix4.translationValues(-10, 0, 0),
        child: CodeEditor(
          controller: _controller,
          focusNode: _focusNode,
          autofocus: false,
          wordWrap: true,
          toolbarController: _toolbarController, // 선언한 컨트롤러 사용
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
                      leadingDistribution: TextLeadingDistribution.even,
                    ),
                    focusedTextStyle: TextStyle(
                      color: AppColors.cBrand600,
                      fontSize: widget.fontSize,
                      fontFamily: widget.fontFamily,
                      fontWeight: FontWeight.bold,
                      height: widget.lineHeight,
                      leadingDistribution: TextLeadingDistribution.even,
                    ),
                  ),
                );
              },
          style: CodeEditorStyle(
            fontSize: widget.fontSize,
            fontFamily: widget.fontFamily,
            codeTheme: CodeHighlightTheme(
              languages: {
                'plaintext': CodeHighlightThemeMode(mode: langPlaintext),
              },
              theme: isDark ? _darkCodeTheme() : _lightCodeTheme(),
            ),
            backgroundColor: Colors.transparent,
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
