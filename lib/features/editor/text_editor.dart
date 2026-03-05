import 'package:flutter/material.dart';
import 'package:highlight/highlight.dart' show highlight, Node;
import 'highlight_rules.dart';
import '../../models/substitution.dart';
import '../../models/glossary_item.dart';

class TextEditor extends StatefulWidget {
  final ZebraHighlightController controller;
  final FocusNode focusNode;
  final UndoHistoryController? undoController;
  final ValueChanged<String> onChanged;
  final double fontSize;
  final double lineHeight;
  final String fontFamily;
  final List<Substitution> substitutions;
  final List<GlossaryItem> glossary;
  final Function(GlossaryItem)? onGlossaryLongPress;

  const TextEditor({
    super.key,
    required this.controller,
    required this.focusNode,
    this.undoController,
    required this.onChanged,
    required this.fontSize,
    required this.lineHeight,
    required this.fontFamily,
    this.substitutions = const [],
    this.glossary = const [],
    this.onGlossaryLongPress,
  });

  @override
  State<TextEditor> createState() => _TextEditorState();
}

class _TextEditorState extends State<TextEditor> {
  @override
  void initState() {
    super.initState();
    widget.controller.glossary = widget.glossary;
    _updateHighlighting();
  }

  @override
  void didUpdateWidget(TextEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.glossary != oldWidget.glossary) {
      widget.controller.glossary = widget.glossary;
      _updateHighlighting();
    }
  }

  void _updateHighlighting() {
    highlight.registerLanguage(
      'game_tags',
      HighlightRules.buildMode(glossary: widget.glossary),
    );
  }

  void _handleLongPress() {
    final offset = widget.controller.selection.baseOffset;
    if (offset >= 0) {
      final item = widget.controller.getGlossaryItemAt(offset);
      if (item != null) {
        widget.onGlossaryLongPress?.call(item);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onLongPress: _handleLongPress,
      child: TextField(
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
        onChanged: (value) {
          widget.controller.applySubstitutions(widget.substitutions);
          widget.onChanged(widget.controller.text);
        },
      ),
    );
  }
}

class ZebraHighlightController extends TextEditingController {
  bool _isSubstituting = false;
  List<GlossaryItem> _glossary = [];

  set glossary(List<GlossaryItem> value) {
    if (_glossary != value) {
      _glossary = value;
      notifyListeners();
    }
  }

  GlossaryItem? getGlossaryItemAt(int offset) {
    if (offset < 0 || offset >= text.length || _glossary.isEmpty) return null;

    final sortedItems = List<GlossaryItem>.from(_glossary)
      ..sort((a, b) => b.source.length.compareTo(a.source.length));

    for (final item in sortedItems) {
      if (!item.isActive) continue;
      final terms = [item.source, ...item.targets].where((t) => t.isNotEmpty);
      for (final t in terms) {
        final matches = RegExp(RegExp.escape(t)).allMatches(text);
        for (final m in matches) {
          if (offset >= m.start && offset < m.end) return item;
        }
      }
    }
    return null;
  }

  void applySubstitutions(List<Substitution> substitutions) {
    if (_isSubstituting || substitutions.isEmpty) return;
    // ... rest of applySubstitutions ...
    final String currentText = text;
    final TextSelection currentSelection = selection;

    if (!currentSelection.isCollapsed || currentSelection.baseOffset <= 0) {
      return;
    }

    final int caretIdx = currentSelection.baseOffset;

    for (final sub in substitutions) {
      if (!sub.isActive) continue;

      final pattern = sub.pattern;
      if (pattern.isEmpty) continue;

      bool isMatch = false;
      int matchStart = -1;
      int matchEnd = -1;
      bool isSpaceTrigger = pattern.endsWith(' ');

      if (isSpaceTrigger) {
        if (caretIdx >= pattern.length) {
          matchStart = caretIdx - pattern.length;
          matchEnd = caretIdx;
          if (currentText.substring(matchStart, matchEnd) == pattern) {
            isMatch = true;
          }
        }
      } else {
        if (caretIdx >= pattern.length) {
          matchStart = caretIdx - pattern.length;
          matchEnd = caretIdx;
          if (currentText.substring(matchStart, matchEnd) == pattern) {
            isMatch = true;
          }
        }
        if (!isMatch &&
            caretIdx > pattern.length &&
            currentText[caretIdx - 1] == ' ') {
          matchStart = caretIdx - 1 - pattern.length;
          matchEnd = caretIdx - 1;
          if (matchStart >= 0 &&
              currentText.substring(matchStart, matchEnd) == pattern) {
            isMatch = true;
          }
        }
      }

      if (isMatch) {
        _isSubstituting = true;
        final String replacement = sub.replacement;
        final String newText = currentText.replaceRange(
          matchStart,
          matchEnd,
          replacement,
        );
        value = value.copyWith(
          text: newText,
          selection: TextSelection.collapsed(
            offset: matchStart + replacement.length,
          ),
        );
        _isSubstituting = false;
        return;
      }
    }
  }

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
    final double bulletSize = baseFontSize * 0.22;

    final highlightResult = highlight.parse(text, language: 'game_tags');
    final dynamicStyles = HighlightRules.getStyles(_glossary);

    final List<TextSpan> allSpans = _convertNodes(
      highlightResult.nodes!,
      style,
      dynamicStyles,
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

  List<TextSpan> _convertNodes(
    List<Node> nodes,
    TextStyle? baseStyle,
    Map<String, TextStyle> dynamicStyles,
  ) {
    final List<TextSpan> spans = [];
    for (var node in nodes) {
      final TextStyle? nodeStyle = dynamicStyles[node.className] ?? baseStyle;
      if (node.value != null) {
        spans.add(TextSpan(text: node.value, style: nodeStyle));
      } else if (node.children != null) {
        spans.addAll(_convertNodes(node.children!, nodeStyle, dynamicStyles));
      }
    }
    return spans;
  }
}
