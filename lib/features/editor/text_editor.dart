import 'package:flutter/material.dart';
import 'dart:ui' as ui;
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
  final ScrollController _scrollController = ScrollController();
  static const double _vPadding = 12.0;

  @override
  void initState() {
    super.initState();
    highlight.registerLanguage('game_tags', HighlightRules.buildMode());
    // 스크롤 및 텍스트 변경 시 Painter를 다시 그리기 위해 리스너 등록
    _scrollController.addListener(_rebuild);
    widget.controller.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    _scrollController.removeListener(_rebuild);
    widget.controller.removeListener(_rebuild);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color lineColor = isDark ? Colors.white10 : Colors.black12;

    return Stack(
      children: [
        // 1. 배경 밑줄 레이어
        Positioned.fill(
          child: CustomPaint(
            painter: NotebookLinePainter(
              text: widget.controller.text,
              scrollController: _scrollController,
              fontSize: widget.fontSize,
              lineHeight: widget.lineHeight,
              lineColor: lineColor,
              verticalPadding: _vPadding,
              fontFamily: widget.fontFamily,
            ),
          ),
        ),
        // 2. 텍스트 레이어
        TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          scrollController: _scrollController,
          undoController: widget.undoController,
          maxLines: null,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
          strutStyle: StrutStyle(
            fontFamily: widget.fontFamily,
            fontSize: widget.fontSize,
            height: widget.lineHeight,
            forceStrutHeight: true,
            leading: 0,
          ),
          style: TextStyle(
            fontSize: widget.fontSize,
            fontFamily: widget.fontFamily,
            height: widget.lineHeight,
            color: isDark ? Colors.white : Colors.black87,
            backgroundColor: Colors.transparent,
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: _vPadding,
            ),
          ),
          onChanged: widget.onChanged,
        ),
      ],
    );
  }
}

class NotebookLinePainter extends CustomPainter {
  final String text;
  final ScrollController scrollController;
  final double fontSize;
  final double lineHeight;
  final Color lineColor;
  final double verticalPadding;
  final String fontFamily;

  NotebookLinePainter({
    required this.text,
    required this.scrollController,
    required this.fontSize,
    required this.lineHeight,
    required this.lineColor,
    required this.verticalPadding,
    required this.fontFamily,
  }) : super(repaint: scrollController);

  @override
  void paint(Canvas canvas, Size size) {
    final double rowHeight = fontSize * lineHeight;
    // 글자 바닥(Baseline)에 밀착시키기 위한 오프셋 계산
    final double baselineFromRowTop = (rowHeight / 2) + (fontSize * 0.4);

    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontFamily: fontFamily,
          height: lineHeight,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout(maxWidth: size.width - 32);

    final List<ui.LineMetrics> lines = textPainter.computeLineMetrics();
    final double scrollOffset = scrollController.hasClients
        ? scrollController.offset
        : 0.0;

    // 공통 Paint 설정 (녹색 판별 로직 제거)
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.0;

    // 1. 텍스트가 존재하는 줄 그리기
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      double y =
          verticalPadding +
          (line.lineNumber * rowHeight) +
          baselineFromRowTop -
          scrollOffset;

      if (y >= 0 && y <= size.height) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    }

    // 2. 텍스트 이후의 빈 공간 줄 그리기
    double lastLineY =
        verticalPadding +
        (lines.length * rowHeight) +
        baselineFromRowTop -
        scrollOffset;

    while (lastLineY < size.height) {
      if (lastLineY >= 0) {
        canvas.drawLine(
          Offset(0, lastLineY),
          Offset(size.width, lastLineY),
          paint,
        );
      }
      lastLineY += rowHeight;
    }
  }

  @override
  bool shouldRepaint(NotebookLinePainter oldDelegate) {
    return oldDelegate.text != text ||
        oldDelegate.fontSize != fontSize ||
        oldDelegate.lineHeight != lineHeight;
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
    final Color bulletColor = isDark ? Colors.white38 : Colors.black26;
    final double baseFontSize = style?.fontSize ?? 19.0;
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
          finalSpans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: SizedBox(
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
