import 'package:flutter/material.dart';

class RichTextEditor extends StatefulWidget {
  final String initialContent;
  final ValueChanged<String> onChanged;
  final double fontSize;
  final double lineHeight;
  final String fontFamily;

  const RichTextEditor({
    super.key,
    required this.initialContent,
    required this.onChanged,
    required this.fontSize,
    required this.lineHeight,
    required this.fontFamily,
  });

  @override
  State<RichTextEditor> createState() => _RichTextEditorState();
}

class _RichTextEditorState extends State<RichTextEditor> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialContent);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final TextStyle textStyle = TextStyle(
      fontSize: widget.fontSize,
      fontWeight: FontWeight.w700,
      height: widget.lineHeight,
      fontFamily: widget.fontFamily,
      leadingDistribution: TextLeadingDistribution.even,
    );

    const EdgeInsets editorPadding = EdgeInsets.fromLTRB(0, 20, 0, 20);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: Container(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: TextField(
              controller: _controller,
              maxLines: null,
              onChanged: widget.onChanged,
              style: textStyle.copyWith(
                color: isDark ? Colors.white : Colors.black87,
              ),
              cursorColor: isDark ? Colors.white : Colors.black,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: editorPadding,
              ),
            ),
          ),
        );
      },
    );
  }
}
