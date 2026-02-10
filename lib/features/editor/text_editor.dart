import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/plaintext.dart';
import 'highlight_rules.dart';

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

  @override
  void initState() {
    super.initState();
    _controller = CodeLineEditingController();
    _controller.text = widget.initialContent;

    _controller.addListener(() {
      widget.onChanged(_controller.text);
    });
  }

  @override
  void didUpdateWidget(covariant TextEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialContent != widget.initialContent &&
        _controller.text != widget.initialContent) {
      _controller.text = widget.initialContent;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      // 1. 에디터 전체를 왼쪽으로 당겨 텍스트 박스를 확장합니다.
      // 글자 크기가 커질수록 이 값을 더 키우면(-40 등) 왼쪽으로 더 붙습니다.
      transform: Matrix4.translationValues(-10, 0, 0),
      child: CodeEditor(
        controller: _controller,
        wordWrap: true,
        indicatorBuilder:
            (context, editingController, chunkController, notifier) {
              // 2. 글자 크기에 따라 줄 번호 너비가 변하므로 최소 너비만 보장합니다.
              return Container(
                constraints: const BoxConstraints(minWidth: 50),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 8),
                child: DefaultCodeLineNumber(
                  controller: editingController,
                  notifier: notifier,
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
