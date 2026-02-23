import 'package:flutter/material.dart';
import 'package:highlight/highlight.dart' show highlight, Node;
import 'highlight_rules.dart';

class TextEditor extends StatefulWidget {
  final ZebraHighlightController controller;
  final FocusNode focusNode;
  final UndoHistoryController? undoController;
  final ValueChanged<String> onChanged;
  final double fontSize;
  final double lineHeight;
  final String fontFamily;

  const TextEditor({
    super.key,
    required this.controller,
    required this.focusNode,
    this.undoController,
    required this.onChanged,
    required this.fontSize,
    required this.lineHeight,
    required this.fontFamily,
  });

  @override
  State<TextEditor> createState() => _TextEditorState();
}

class _TextEditorState extends State<TextEditor> {
  @override
  void initState() {
    super.initState();
    highlight.registerLanguage('game_tags', HighlightRules.buildMode());
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      undoController: widget.undoController,
      maxLines: null,
      expands: true,
      textAlignVertical: TextAlignVertical.center,
      style: TextStyle(
        fontSize: widget.fontSize,
        fontFamily: widget.fontFamily,
        height: widget.lineHeight,
        color: isDark ? Colors.white : Colors.black87,
      ),
      decoration: const InputDecoration(
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      onChanged: widget.onChanged,
    );
  }
}

class ZebraHighlightController extends TextEditingController {
  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bulletColor = isDark
        ? Colors.white.withAlpha(100)
        : Colors.black.withAlpha(80);

    final double baseFontSize = style?.fontSize ?? 19.0;
    // 폰트 크기에 비례하는 불릿 크기 (고정폭 폰트에서도 일정한 비율 유지)
    final double bulletSize = baseFontSize * 0.22;

    final highlightResult = highlight.parse(text, language: 'game_tags');
    final List<TextSpan> allSpans = _convertNodes(
      highlightResult.nodes!,
      style,
    );

    final List<InlineSpan> finalSpans = [];

    for (var span in allSpans) {
      final String spanText = span.text ?? '';
      if (spanText.isEmpty) continue;

      for (int i = 0; i < spanText.length; i++) {
        final String char = spanText[i];

        if (char == ' ') {
          // 1. 공백 1글자를 정확히 1개의 WidgetSpan으로 치환 (인덱스 보존)
          finalSpans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: SizedBox(
                // 중요: 폰트의 실제 공백 너비 비율(약 0.3~0.4)을 강제 고정
                width: baseFontSize * 0.4,
                child: Center(
                  child: Container(
                    width: bulletSize,
                    height: bulletSize,
                    decoration: BoxDecoration(
                      color: bulletColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          );
        } else {
          // 2. 일반 문자 및 개행은 기존 스타일 그대로 유지
          finalSpans.add(TextSpan(text: char, style: span.style));
        }
      }
    }

    return TextSpan(style: style, children: finalSpans);
  }

  List<TextSpan> _convertNodes(List<Node> nodes, TextStyle? baseStyle) {
    final List<TextSpan> spans = [];
    for (var node in nodes) {
      final TextStyle? nodeStyle =
          HighlightRules.gameTagPatterns[node.className] ?? baseStyle;
      if (node.value != null) {
        spans.add(TextSpan(text: node.value, style: nodeStyle));
      } else if (node.children != null) {
        spans.addAll(_convertNodes(node.children!, nodeStyle));
      }
    }
    return spans;
  }
}
