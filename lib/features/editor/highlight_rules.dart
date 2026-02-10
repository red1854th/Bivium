import 'package:flutter/material.dart';
import 'package:re_highlight/re_highlight.dart';

class HighlightRules {
  // 1. 스타일 정의
  static Map<String, TextStyle> get gameTagPatterns => {
    'color-red': const TextStyle(color: Color(0xFFFF5555)),
    'color-blue': const TextStyle(color: Color(0xFF5555FF)),
    'color-green': const TextStyle(color: Color(0xFF55FF55)),
    'color-any': const TextStyle(color: Color(0xFF4FC1FF)), // 기본 블루
    'section-range': const TextStyle(color: Color(0xFFC586C0)),
    'tag-style': const TextStyle(color: Colors.orangeAccent),
  };

  // 2. 엔진 주입용 문법 모드 생성
  static Mode buildMode() {
    return Mode(
      contains: [
        // 특정 색상(Red) 판별 및 구간 전체 색칠
        Mode(
          className: 'color-red',
          begin: r'<color=(?:red|#FF0000|#ff0000)>',
          end: r'<\/color>',
        ),
        // 특정 색상(Blue) 판별 및 구간 전체 색칠
        Mode(
          className: 'color-blue',
          begin: r'<color=(?:blue|#0000FF|#0000ff)>',
          end: r'<\/color>',
        ),
        // 특정 색상(Green) 판별 및 구간 전체 색칠
        Mode(
          className: 'color-green',
          begin: r'<color=(?:green|#00FF00|#00ff00)>',
          end: r'<\/color>',
        ),
        // 그 외 모든 <color> 구간 전체 색칠
        Mode(
          className: 'color-any',
          begin: r'<color=[^>]+>',
          end: r'<\/color>',
        ),
        // §. ... 한 줄 범위 전체 색칠
        Mode(
          className: 'section-range',
          begin: r'§[0-9a-fA-fk-orR]',
          end: r'$|§r',
        ),
        // 단발성 태그
        Mode(className: 'tag-style', begin: r'<\/?(?:b|i|size(?:=[^>]+)?)>'),
      ],
    );
  }
}
