import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:bivium/core/theme.dart';

class SheetCell extends StatefulWidget {
  final String value;
  final bool isDark;
  final ValueChanged<String> onChanged;
  final bool isMonospace;
  final bool isSmall;
  final bool isBold;
  final double width;
  final String cellId;
  final bool isEditing;
  final ValueChanged<String?> onStartEditing;

  const SheetCell({
    super.key,
    required this.value,
    required this.isDark,
    required this.onChanged,
    required this.width,
    required this.cellId,
    required this.isEditing,
    required this.onStartEditing,
    this.isMonospace = false,
    this.isSmall = false,
    this.isBold = false,
  });

  @override
  State<SheetCell> createState() => _SheetCellState();
}

class _SheetCellState extends State<SheetCell> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode.addListener(_handleFocusChange);
    _controller.addListener(_onTextChanged);

    if (widget.isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showOverlay());
    }
  }

  void _onTextChanged() {
    // 텍스트가 변경될 때마다 Overlay를 다시 그려서 너비를 업데이트
    _overlayEntry?.markNeedsBuild();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus && widget.isEditing) {
      _submit();
    }
  }

  @override
  void didUpdateWidget(SheetCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !widget.isEditing) {
      _controller.text = widget.value;
    }

    if (oldWidget.isEditing != widget.isEditing) {
      if (widget.isEditing) {
        _controller.text = widget.value;
        _showOverlay();
      } else {
        if (_controller.text != widget.value) {
          widget.onChanged(_controller.text);
        }
        _hideOverlay();
      }
    }
  }

  @override
  void dispose() {
    _hideOverlay();
    _controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  double _measureTextWidth() {
    final text = _controller.text.isEmpty ? ' ' : _controller.text;
    final style = TextStyle(
      fontSize: widget.isSmall ? 11 : 12,
      fontFamily: widget.isMonospace ? 'monospace' : null,
      fontWeight: widget.isBold ? FontWeight.bold : FontWeight.normal,
    );
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    return painter.width;
  }

  void _showOverlay() {
    _hideOverlay();
    final overlayState = Overlay.of(context);

    _overlayEntry = OverlayEntry(
      builder: (_) {
        // 텍스트 너비 측정 후 셀 너비와 비교
        final double textWidth = _measureTextWidth();
        final double contentWidth = textWidth + 24; // 패딩 + 커서 여유
        // 기존 셀 너비보다 텍스트가 길면 확장, 아니면 셀 너비 유지
        final double overlayWidth = contentWidth > widget.width
            ? contentWidth
            : widget.width + 4;

        return CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(-2, -2),
          child: Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(2),
              color: widget.isDark ? AppColors.cDarkBg : Colors.white,
              child: Container(
                width: overlayWidth,
                constraints: const BoxConstraints(minHeight: 48),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(color: AppColors.cBrand600, width: 2),
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: true,
                  maxLines: null,
                  minLines: 1,
                  textAlignVertical: TextAlignVertical.center,
                  style: TextStyle(
                    color: widget.isDark ? Colors.white : AppColors.cSlate900,
                    fontSize: widget.isSmall ? 11 : 12,
                    fontFamily: widget.isMonospace ? 'monospace' : null,
                    fontWeight: widget.isBold
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                  onSubmitted: (_) => _submit(),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlayState.insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _submit() {
    if (_controller.text != widget.value) {
      widget.onChanged(_controller.text);
    }
    if (widget.isEditing) {
      widget.onStartEditing(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: InkWell(
        onTap: () {
          if (!widget.isEditing) {
            widget.onStartEditing(widget.cellId);
          }
        },
        child: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Opacity(
            opacity: widget.isEditing ? 0.0 : 1.0,
            child: Text(
              widget.value.replaceAll('\n', ' '),
              style: TextStyle(
                color: widget.isDark ? Colors.white70 : AppColors.cSlate700,
                fontSize: widget.isSmall ? 11 : 12,
                fontFamily: widget.isMonospace ? 'monospace' : null,
                fontWeight: widget.isBold ? FontWeight.bold : FontWeight.normal,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}
