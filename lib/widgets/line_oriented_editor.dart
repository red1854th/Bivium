import 'package:flutter/material.dart';

class LineOrientedEditor extends StatelessWidget {
  final TextEditingController controller;
  final InputDecoration decoration;
  final int? maxLines;

  const LineOrientedEditor({
    super.key,
    required this.controller,
    this.decoration = const InputDecoration(), // Provide a default decoration
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: decoration,
      maxLines: maxLines,
      keyboardType:
          TextInputType.multiline, // Often useful for multi-line text input
    );
  }
}
