import 'dart:convert';
import '../features/home/setting_page.dart';

class Substitution implements ManageableItem {
  @override
  String get id => pattern;
  final String pattern;
  final String replacement;
  @override
  final bool isActive;
  @override
  final String group;

  Substitution({
    required this.pattern,
    required this.replacement,
    this.isActive = true,
    this.group = '',
  });

  @override
  Map<String, dynamic> toJson() => {
    'pattern': pattern,
    'replacement': replacement,
    'isActive': isActive,
    'group': group,
  };

  factory Substitution.fromJson(Map<String, dynamic> json) => Substitution(
    pattern: json['pattern'],
    replacement: json['replacement'],
    isActive: json['isActive'] ?? true,
    group: json['group'] ?? '',
  );

  static String serializeList(List<Substitution> substitutions) {
    return jsonEncode(substitutions.map((e) => e.toJson()).toList());
  }

  static List<Substitution> deserializeList(String jsonString) {
    if (jsonString.isEmpty) return [];
    try {
      final List<dynamic> decoded = jsonDecode(jsonString);
      return decoded.map((e) => Substitution.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Substitution copyWith({
    String? pattern,
    String? replacement,
    bool? isActive,
    String? group,
  }) {
    return Substitution(
      pattern: pattern ?? this.pattern,
      replacement: replacement ?? this.replacement,
      isActive: isActive ?? this.isActive,
      group: group ?? this.group,
    );
  }
}
