import 'package:flutter/material.dart';
import 'package:highlight/highlight.dart' show highlight, Node;
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
  late ZebraHighlightController _controller;

  @override
  void initState() {
    super.initState();
    // 1. 사용자 정의 언어 규칙 등록
    highlight.registerLanguage('game_tags', HighlightRules.buildMode());

    _controller = ZebraHighlightController();
    _controller.text = widget.initialContent;
    _controller.addListener(() => widget.onChanged(_controller.text));
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return TextField(
      controller: _controller,
      maxLines: null,
      expands: true,
      textAlignVertical: TextAlignVertical.center,
      style: TextStyle(
        fontSize: widget.fontSize,
        fontFamily: widget.fontFamily,
        height: widget.lineHeight,
        color: isDark ? Colors.white : Colors.black87,
      ),
      strutStyle: StrutStyle(
        fontSize: widget.fontSize,
        height: widget.lineHeight,
        forceStrutHeight: true,
      ),
      decoration: const InputDecoration(
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
      ),
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
    final Color zebraColor = isDark
        ? Colors.white.withAlpha(15)
        : Colors.black.withAlpha(10);

    // 2. 등록된 언어 이름('game_tags')으로 파싱
    final highlightResult = highlight.parse(text, language: 'game_tags');
    final List<TextSpan> allSpans = _convertNodes(
      highlightResult.nodes!,
      style,
    );

    final List<TextSpan> zebraSpans = [];
    final List<TextSpan> currentLineSpans = [];
    int lineIndex = 0;

    void flushLine() {
      final bool isEven = lineIndex % 2 == 1;
      final TextStyle? lineStyle = isEven
          ? style?.copyWith(backgroundColor: zebraColor)
          : style;

      zebraSpans.add(
        TextSpan(style: lineStyle, children: List.from(currentLineSpans)),
      );
      currentLineSpans.clear();
      lineIndex++;
    }

    for (var span in allSpans) {
      final String spanText = span.text ?? '';
      if (spanText.isEmpty) continue;

      final List<String> parts = spanText.split('\n');
      for (int i = 0; i < parts.length; i++) {
        if (parts[i].isNotEmpty) {
          currentLineSpans.add(TextSpan(text: parts[i], style: span.style));
        }
        if (i < parts.length - 1) {
          currentLineSpans.add(const TextSpan(text: '\n'));
          flushLine();
        }
      }
    }
    if (currentLineSpans.isNotEmpty || text.endsWith('\n')) {
      flushLine();
    }

    return TextSpan(style: style, children: zebraSpans);
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
