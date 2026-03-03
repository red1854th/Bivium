import 'package:flutter/material.dart';

enum ToolbarItemType {
  undo,
  redo,
  insertCheckbox,
  moveLeft,
  moveRight,
  hideKeyboard,
}

class ToolbarItem {
  final ToolbarItemType type;
  final bool isVisible;

  ToolbarItem({required this.type, this.isVisible = true});

  String get id => type.name;

  IconData get icon {
    switch (type) {
      case ToolbarItemType.undo:
        return Icons.undo_rounded;
      case ToolbarItemType.redo:
        return Icons.redo_rounded;
      case ToolbarItemType.insertCheckbox:
        return Icons.add_box_outlined;
      case ToolbarItemType.moveLeft:
        return Icons.arrow_back_ios_new_rounded;
      case ToolbarItemType.moveRight:
        return Icons.arrow_forward_ios_rounded;
      case ToolbarItemType.hideKeyboard:
        return Icons.keyboard_hide_rounded;
    }
  }

  String get label {
    switch (type) {
      case ToolbarItemType.undo:
        return 'Undo';
      case ToolbarItemType.redo:
        return 'Redo';
      case ToolbarItemType.insertCheckbox:
        return 'Insert Checkbox';
      case ToolbarItemType.moveLeft:
        return 'Move Cursor Left';
      case ToolbarItemType.moveRight:
        return 'Move Cursor Right';
      case ToolbarItemType.hideKeyboard:
        return 'Hide Keyboard';
    }
  }

  Map<String, dynamic> toJson() => {'type': type.name, 'isVisible': isVisible};

  factory ToolbarItem.fromJson(Map<String, dynamic> json) {
    return ToolbarItem(
      type: ToolbarItemType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ToolbarItemType.undo,
      ),
      isVisible: json['isVisible'] ?? true,
    );
  }

  ToolbarItem copyWith({bool? isVisible}) {
    return ToolbarItem(type: type, isVisible: isVisible ?? this.isVisible);
  }
}
