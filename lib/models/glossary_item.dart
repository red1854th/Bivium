import 'dart:convert';
import '../features/home/setting_page.dart';

class GlossaryItem implements ManageableItem {
  @override
  final String id;
  final String source;
  final List<String> targets;
  final String color; // Hex string e.g. "#FF5555"
  @override
  final String group;
  @override
  final bool isActive;

  GlossaryItem({
    required this.id,
    required this.source,
    this.targets = const [],
    this.color = '#4FC1FF',
    this.group = '',
    this.isActive = true,
  });

  @override
  GlossaryItem copyWith({
    String? id,
    String? source,
    List<String>? targets,
    String? color,
    String? group,
    bool? isActive,
  }) {
    return GlossaryItem(
      id: id ?? this.id,
      source: source ?? this.source,
      targets: targets ?? this.targets,
      color: color ?? this.color,
      group: group ?? this.group,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'source': source,
      'targets': targets,
      'color': color,
      'group': group,
      'isActive': isActive,
    };
  }

  factory GlossaryItem.fromJson(Map<String, dynamic> json) {
    return GlossaryItem(
      id: json['id'] ?? (json['source'] ?? ''),
      source: json['source'] ?? '',
      targets: List<String>.from(json['targets'] ?? []),
      color: json['color'] ?? '#4FC1FF',
      group: json['group'] ?? '',
      isActive: json['isActive'] ?? true,
    );
  }

  static String serializeList(List<GlossaryItem> list) {
    return jsonEncode(list.map((item) => item.toJson()).toList());
  }

  static List<GlossaryItem> deserializeList(String jsonStr) {
    if (jsonStr.isEmpty) return [];
    try {
      final List<dynamic> decoded = jsonDecode(jsonStr);
      return decoded.map((item) => GlossaryItem.fromJson(item)).toList();
    } catch (e) {
      return [];
    }
  }
}
