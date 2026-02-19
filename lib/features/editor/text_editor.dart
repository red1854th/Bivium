import 'package:flutter/material.dart';
import 'package:highlight/highlight.dart' show highlight, Node;
import 'highlight_rules.dart';

class TextEditor extends StatefulWidget {
  final ZebraHighlightController controller;
  final FocusNode focusNode;
  final UndoHistoryController? undoController; // 전달받은 컨트롤러
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
      undoController: widget.undoController, // [필수] 이 부분이 연결되어야 작동함
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
