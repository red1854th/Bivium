import 'package:flutter/material.dart';
import 'package:highlight/highlight.dart';

class HighlightRules {
  static Map<String, TextStyle> get gameTagPatterns => {
    'color-red': const TextStyle(color: Color(0xFFFF5555)),
    'color-blue': const TextStyle(color: Color(0xFF5555FF)),
    'color-green': const TextStyle(color: Color(0xFF55FF55)),
    'color-any': const TextStyle(color: Color(0xFF4FC1FF)),
    'section-range': const TextStyle(color: Color(0xFFC586C0)),
    'tag-style': const TextStyle(color: Colors.orangeAccent),
  };

  static Mode buildMode() {
    return Mode(
      // 'name' 파라미터를 제거했습니다.
      contains: [
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
        Mode(
          className: 'color-any',
          begin: r'<color=[^>]+>',
          end: r'<\/color>',
        ),
        Mode(
          className: 'section-range',
          begin: r'§[0-9a-fA-fk-orR]',
          end: r'$|§r',
        ),
        Mode(className: 'tag-style', begin: r'<\/?(?:b|i|size(?:=[^>]+)?)>'),
      ],
    );
  }
}
