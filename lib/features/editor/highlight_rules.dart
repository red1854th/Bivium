import 'package:flutter/material.dart';

class HighlightRules {
  static Map<String, TextStyle> get gameTagPatterns => {
    // (?: )를 사용하여 캡처 그룹화로 인한 인덱스 오류 방지
    r"<color=[^>]+>": const TextStyle(color: Colors.blueAccent),
    r"</color>": const TextStyle(color: Colors.blueAccent),

    // (b|i|size) 대신 (?:b|i|size) 사용
    r"</?(?:b|i|size(?:=[^>]+)?)>": const TextStyle(color: Colors.orangeAccent),

    // 섹션 기호 스타일
    r"§.": const TextStyle(
      color: Colors.greenAccent,
      fontWeight: FontWeight.bold,
    ),
  };
}
