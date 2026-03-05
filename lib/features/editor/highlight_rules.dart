import 'package:flutter/material.dart';
import 'package:highlight/highlight.dart';
import '../../models/glossary_item.dart';

class HighlightRules {
  static Map<String, TextStyle> get gameTagPatterns => {
    'color-red': const TextStyle(color: Color(0xFFFF5555)),
    'color-blue': const TextStyle(color: Color(0xFF5555FF)),
    'color-green': const TextStyle(color: Color(0xFF55FF55)),
    'color-any': const TextStyle(color: Color(0xFF4FC1FF)),
    'section-range': const TextStyle(color: Color(0xFFC586C0)),
    'tag-style': const TextStyle(color: Colors.orangeAccent),
  };

  static String buildGlossaryRegex(String term) {
    if (term.isEmpty) return '';

    String makeCaseInsensitive(String text) {
      return text
          .split('')
          .map((char) {
            if (RegExp(r'[a-zA-Z]').hasMatch(char)) {
              return '[${char.toLowerCase()}${char.toUpperCase()}]';
            }
            return RegExp.escape(char);
          })
          .join('');
    }

    final isEnglish = RegExp(r'^[a-zA-Z\s\-]+$').hasMatch(term);
    if (!isEnglish) {
      return makeCaseInsensitive(term);
    }

    String pattern;
    if (term.toLowerCase().endsWith('y')) {
      final base = makeCaseInsensitive(term.substring(0, term.length - 1));
      pattern = '$base(?:[yY]|[iI][eE][sS])';
    } else if (RegExp(r'(s|x|z|ch|sh)$', caseSensitive: false).hasMatch(term)) {
      final base = makeCaseInsensitive(term);
      pattern = '$base(?:[eE][sS])?';
    } else {
      final base = makeCaseInsensitive(term);
      pattern = '$base(?:[sS]|[eE][sS])?';
    }
    return '\\b$pattern\\b';
  }

  static Mode buildMode({List<GlossaryItem> glossary = const []}) {
    final List<Mode> contains = [
      Mode(
        className: 'color-red',
        begin: r'<color=(?:red|#FF0000|#ff0000)>',
        end: r'<\/color>',
      ),
      Mode(
        className: 'color-blue',
        begin: r'<color=(?:blue|#0000FF|#0000ff)>',
        end: r'<\/color>',
      ),
      Mode(
        className: 'color-green',
        begin: r'<color=(?:green|#00FF00|#00ff00)>',
        end: r'<\/color>',
      ),
      Mode(className: 'color-any', begin: r'<color=[^>]+>', end: r'<\/color>'),
      Mode(
        className: 'section-range',
        begin: r'§[0-9a-fA-fk-orR]',
        end: r'$|§r',
      ),
      Mode(className: 'tag-style', begin: r'<\/?(?:b|i|size(?:=[^>]+)?)>'),
    ];

    // Create a flat list of (term, id) for all glossary items
    final List<({String term, String id})> flatTerms = [];
    for (final item in glossary) {
      if (!item.isActive) continue;
      if (item.source.isNotEmpty) {
        flatTerms.add((term: item.source, id: item.id));
      }
      for (final t in item.targets) {
        if (t.isNotEmpty) {
          flatTerms.add((term: t, id: item.id));
        }
      }
    }

    // Sort by length descending to achieve "Longest Match"
    flatTerms.sort((a, b) => b.term.length.compareTo(a.term.length));

    // Add as separate modes in sorted order
    for (final mapping in flatTerms) {
      final regexStr = buildGlossaryRegex(mapping.term);
      if (regexStr.isNotEmpty) {
        contains.add(
          Mode(className: 'glossary-${mapping.id}', begin: regexStr),
        );
      }
    }

    return Mode(contains: contains);
  }

  static Map<String, TextStyle> getStyles(List<GlossaryItem> glossary) {
    final Map<String, TextStyle> styles = Map.from(gameTagPatterns);
    for (final item in glossary) {
      styles['glossary-${item.id}'] = TextStyle(
        color: Color(int.parse(item.color.replaceFirst('#', '0xFF'))),
        fontWeight: FontWeight.bold,
        decoration: TextDecoration.underline,
        decorationColor: Color(
          int.parse(item.color.replaceFirst('#', '0xFF')),
        ).withAlpha(120),
        decorationThickness: 1.5,
      );
    }
    return styles;
  }
}
