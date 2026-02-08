import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bivium/models/flashcard.dart';
import 'package:bivium/services/dictionary_service.dart';

class AnalyzedWord {
  final String original, main, tail;
  final bool isTypo;
  final int cardIndex;

  AnalyzedWord({
    required this.original,
    required this.main,
    required this.tail,
    required this.isTypo,
    required this.cardIndex,
  });

  Map<String, dynamic> toJson() => {
    'original': original,
    'main': main,
    'tail': tail,
    'isTypo': isTypo,
    'cardIndex': cardIndex,
  };

  factory AnalyzedWord.fromJson(Map<String, dynamic> json) => AnalyzedWord(
    original: json['original'],
    main: json['main'],
    tail: json['tail'],
    isTypo: json['isTypo'],
    cardIndex: json['cardIndex'],
  );
}

class _AnalysisData {
  final List<Flashcard> cards;
  final List<String> meongsa, eogeun, suffixes;
  _AnalysisData(this.cards, this.meongsa, this.eogeun, this.suffixes);
}

class AnalysisService {
  static final AnalysisService _instance = AnalysisService._internal();
  factory AnalysisService() => _instance;
  AnalysisService._internal();

  static const String _cachePrefix = "analysis_cache_";

  // 비동기 분석 실행
  Future<Map<String, List<AnalyzedWord>>> analyzeAsync(
    List<Flashcard> cards,
    DictionaryService dict,
  ) async {
    if (!dict.isInitialized || cards.isEmpty) return {};
    final data = _AnalysisData(
      cards,
      dict.meongsa.toList(),
      dict.eogeun.toList(),
      [...dict.josa, ...dict.eomaleomi, ...dict.seoneomaleomi],
    );
    return await compute(_heavyAnalysisTask, data);
  }

  // 영구 저장
  Future<void> saveToLocal(
    String sheetId,
    Map<String, List<AnalyzedWord>> data,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(
      data.map((k, v) => MapEntry(k, v.map((w) => w.toJson()).toList())),
    );
    await prefs.setString('$_cachePrefix$sheetId', encoded);
  }

  // 로컬 데이터 불러오기
  Future<Map<String, List<AnalyzedWord>>?> loadFromLocal(String sheetId) async {
    final prefs = await SharedPreferences.getInstance();
    final String? encoded = prefs.getString('$_cachePrefix$sheetId');
    if (encoded == null) return null;
    final Map<String, dynamic> decoded = jsonDecode(encoded);
    return decoded.map(
      (k, v) => MapEntry(
        k,
        (v as List).map((i) => AnalyzedWord.fromJson(i)).toList(),
      ),
    );
  }
}

// Isolate에서 동작할 무거운 연산 (Null Safety 강화)
Map<String, List<AnalyzedWord>> _heavyAnalysisTask(_AnalysisData data) {
  final Map<String, List<AnalyzedWord>> groups = {};
  final wordPattern = RegExp(r'[a-zA-Z\uAC00-\uD7A3]+');
  final Map<String, Set<int>> wordToIndices = {};

  for (int i = 0; i < data.cards.length; i++) {
    final text = '${data.cards[i].front} ${data.cards[i].back}';
    for (final match in wordPattern.allMatches(text)) {
      final w = match.group(0);
      if (w != null && w.isNotEmpty) {
        wordToIndices.putIfAbsent(w, () => {}).add(i);
      }
    }
  }

  final contents = [...data.meongsa, ...data.eogeun]
    ..sort((a, b) => b.length.compareTo(a.length));
  final suffixes = data.suffixes..sort((a, b) => b.length.compareTo(a.length));

  for (final word in wordToIndices.keys) {
    final indices = wordToIndices[word] ?? {};
    bool matched = false;
    for (final stem in contents) {
      if (word.startsWith(stem)) {
        final rest = word.substring(stem.length);
        if (rest.isEmpty || _checkSuffixChain(rest, suffixes)) {
          for (final idx in indices) {
            groups
                .putIfAbsent(stem, () => [])
                .add(
                  AnalyzedWord(
                    original: word,
                    main: stem,
                    tail: rest,
                    isTypo: false,
                    cardIndex: idx,
                  ),
                );
          }
          matched = true;
          break;
        }
      }
    }
    if (!matched) {
      for (final idx in indices) {
        groups
            .putIfAbsent(word, () => [])
            .add(
              AnalyzedWord(
                original: word,
                main: word,
                tail: "",
                isTypo: true,
                cardIndex: idx,
              ),
            );
      }
    }
  }
  return groups;
}

bool _checkSuffixChain(String text, List<String> dict) {
  String temp = text;
  while (temp.isNotEmpty) {
    bool found = false;
    for (final s in dict) {
      if (temp.startsWith(s)) {
        temp = temp.substring(s.length);
        found = true;
        break;
      }
    }
    if (!found) return false;
  }
  return true;
}
