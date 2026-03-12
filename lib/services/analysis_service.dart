import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bivium/models/flashcard.dart';

class AnalyzedWord {
  final String original, main, tail;
  final bool isTypo;
  final int cardIndex;
  final int frequency;
  final double typoScore;

  AnalyzedWord({
    required this.original,
    required this.main,
    required this.tail,
    required this.isTypo,
    required this.cardIndex,
    required this.frequency,
    required this.typoScore,
  });

  Map<String, dynamic> toJson() => {
    'original': original,
    'main': main,
    'tail': tail,
    'isTypo': isTypo,
    'cardIndex': cardIndex,
    'frequency': frequency,
    'typoScore': typoScore,
  };

  factory AnalyzedWord.fromJson(Map<String, dynamic> json) => AnalyzedWord(
    original: json['original'],
    main: json['main'],
    tail: json['tail'],
    isTypo: json['isTypo'],
    cardIndex: json['cardIndex'],
    frequency: json['frequency'] ?? 1,
    typoScore: (json['typoScore'] ?? 0.0).toDouble(),
  );
}

class SimilarGroup {
  final List<Flashcard> cards;
  final double similarity;
  final String commonPart;

  SimilarGroup({
    required this.cards,
    required this.similarity,
    required this.commonPart,
  });
}

class AnalysisService {
  static final AnalysisService _instance = AnalysisService._internal();
  factory AnalysisService() => _instance;
  AnalysisService._internal();

  static const String _cachePrefix = "analysis_cache_";

  // 비동기 분석 실행
  Future<Map<String, List<AnalyzedWord>>> analyzeAsync(
    List<Flashcard> cards,
  ) async {
    if (cards.isEmpty) return {};

    // 에셋 로딩은 메인 스레드에서 수행 (매우 빠름, Isolate 접근 문제 방지)
    final filenames = [
      'meongsa.dic',
      'eogeun.dic',
      'danwi.dic',
      'jeopdusa.dic',
      'josa.dic',
      'eomaleomi.dic',
      'seoneomaleomi.dic',
      'jeopmisa.dic',
    ];

    final Map<String, String> dictContents = {};
    for (final name in filenames) {
      try {
        dictContents[name] = await rootBundle.loadString('assets/dict/$name');
      } catch (e) {
        debugPrint("Failed to load dictionary $name: $e");
        dictContents[name] = "";
      }
    }

    final data = _AnalysisData(cards: cards, dicts: dictContents);

    // 실제 무거운 파싱 및 분석 연산은 백그라운드 Isolate에서 수행
    return compute(_heavyAnalysisTask, data);
  }

  // 유사 텍스트 분석 (Front 기준)
  Future<List<SimilarGroup>> findSimilarCardsAsync(
    List<Flashcard> cards,
  ) async {
    if (cards.length < 2) return [];
    return compute(_findSimilarTask, cards);
  }

  // 검색어 기반 유사 그룹 생성 (Front + Back 포함, 유동적 바인딩)
  Future<List<SimilarGroup>> findSimilarByQueryAsync({
    required List<Flashcard> cards,
    required String query,
  }) async {
    if (query.isEmpty) return [];
    return compute(_findSimilarByQueryTask, {'cards': cards, 'query': query});
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

class _AnalysisData {
  final List<Flashcard> cards;
  final Map<String, String> dicts;
  _AnalysisData({required this.cards, required this.dicts});
}

class _DictEntry {
  final String word;
  final String jamo;
  _DictEntry(this.word, this.jamo);
}

// Isolate에서 동작할 무거운 연산
Map<String, List<AnalyzedWord>> _heavyAnalysisTask(_AnalysisData data) {
  final results = <String, List<AnalyzedWord>>{};
  final wordPattern = RegExp(r'[a-zA-Z\uAC00-\uD7A3]+');
  final Set<String> contentSet = {};
  final Set<String> suffixSet = {};

  void parseAndAdd(String? text, Set<String> target) {
    if (text == null || text.isEmpty) return;
    for (final line in text.split('\n')) {
      final cleaned = line.replaceAll('-', '').trim();
      if (cleaned.isNotEmpty) target.add(cleaned);
    }
  }

  // 전달받은 원문 텍스트를 파싱하여 Set 구축
  parseAndAdd(data.dicts['meongsa.dic'], contentSet);
  parseAndAdd(data.dicts['eogeun.dic'], contentSet);
  parseAndAdd(data.dicts['danwi.dic'], contentSet);
  parseAndAdd(data.dicts['jeopdusa.dic'], contentSet);

  parseAndAdd(data.dicts['josa.dic'], suffixSet);
  parseAndAdd(data.dicts['eomaleomi.dic'], suffixSet);
  parseAndAdd(data.dicts['seoneomaleomi.dic'], suffixSet);
  parseAndAdd(data.dicts['jeopmisa.dic'], suffixSet);

  final List<String> sortedSuffixes = suffixSet.toList()
    ..sort((a, b) => b.length.compareTo(a.length));

  final Map<String, int> globalFreq = {};
  final wordToIndices = <String, List<int>>{};
  for (int i = 0; i < data.cards.length; i++) {
    // 뒷면(번역문) 텍스트만 분석 대상으로 설정
    final text = data.cards[i].back;
    for (final match in wordPattern.allMatches(text)) {
      final w = match.group(0)!;
      globalFreq[w] = (globalFreq[w] ?? 0) + 1;
      wordToIndices.putIfAbsent(w, () => []).add(i);
    }
  }

  // 사전 Jamo 미리 계산하여 검색 속도 최적화
  final Map<int, List<_DictEntry>> dictJamoByLen = {};
  for (final w in contentSet) {
    dictJamoByLen
        .putIfAbsent(w.length, () => [])
        .add(_DictEntry(w, _toJamo(w)));
  }

  for (final word in globalFreq.keys) {
    final freq = globalFreq[word]!;
    final indices = wordToIndices[word]!;

    String analyzedStem = word;
    String analyzedSuffix = "";
    bool matched = false;

    // 1. 단순 일치 또는 형태소 분석
    if (contentSet.contains(word) || suffixSet.contains(word)) {
      matched = true;
    } else {
      // Longest suffix match
      for (final s in sortedSuffixes) {
        if (word.length > s.length && word.endsWith(s)) {
          final st = word.substring(0, word.length - s.length);
          if (contentSet.contains(st)) {
            analyzedStem = st;
            analyzedSuffix = s;
            matched = true;
            break;
          }
        }
      }

      if (!matched) {
        // Recursive split check
        for (int i = word.length - 1; i >= 1; i--) {
          final st = word.substring(0, i);
          final su = word.substring(i);
          if (contentSet.contains(st) && _isValidSuffixChain(su, suffixSet)) {
            analyzedStem = st;
            analyzedSuffix = su;
            matched = true;
            break;
          }
        }
      }
    }

    double typoScore = 0.0;
    String? closestWord;

    if (!matched && freq < 2 && word.length >= 2) {
      final wordJamo = _toJamo(word);
      int minJamoDist = 999;
      String bestTarget = "";
      int searchCount = 0;

      for (int l = word.length - 1; l <= word.length + 1; l++) {
        final entries = dictJamoByLen[l];
        if (entries == null) continue;
        for (final entry in entries) {
          if (searchCount++ > 1500) break; // 성능을 위해 후보 탐색 제한
          if (word[0] != entry.word[0] && word.length > 2) continue;

          final d = _levenshtein(wordJamo, entry.jamo);
          if (d < minJamoDist) {
            minJamoDist = d;
            bestTarget = entry.word;
          }
          if (minJamoDist <= 1) break;
        }
        if (minJamoDist <= 1 || searchCount > 1500) break;
      }

      if (minJamoDist <= 3) {
        typoScore = (minJamoDist * 8.0).clamp(5.0, 25.0);
        closestWord = bestTarget;
      } else if (minJamoDist < 10) {
        typoScore = (40.0 + minJamoDist * 4.0).clamp(30.0, 85.0);
        closestWord = bestTarget;
      } else {
        typoScore = 90.0;
      }
      typoScore += (word.hashCode % 100) * 0.01;
    }

    if (word.length < 2) typoScore = 0.0;

    // 그룹핑은 사용자의 요청대로 '완전 동일한 단어(word)'를 기준으로 하여
    // 사령/사령술사 등이 하나로 묶이는 오작동을 방지함
    final String groupKey = word;

    for (final idx in indices) {
      results
          .putIfAbsent(groupKey, () => [])
          .add(
            AnalyzedWord(
              original: word,
              main: closestWord ?? analyzedStem,
              tail: matched
                  ? analyzedSuffix
                  : (closestWord != null ? "($closestWord?)" : ""),
              isTypo: !matched,
              cardIndex: idx,
              frequency: freq,
              typoScore: typoScore.clamp(0.0, 99.9),
            ),
          );
    }
  }
  return results;
}

// Jamo Decomposition for Hangul
String _toJamo(String text) {
  final sb = StringBuffer();
  for (final char in text.runes) {
    final c = char;
    if (c >= 0xAC00 && c <= 0xD7A3) {
      final idx = c - 0xAC00;
      final cho = idx ~/ (21 * 28);
      final jung = (idx % (21 * 28)) ~/ 28;
      final jong = idx % 28;
      sb.writeCharCode(0x1100 + cho);
      sb.writeCharCode(0x1161 + jung);
      if (jong > 0) sb.writeCharCode(0x11A7 + jong);
    } else {
      sb.writeCharCode(c);
    }
  }
  return sb.toString();
}

int _levenshtein(String s1, String s2) {
  if (s1 == s2) return 0;
  if (s1.isEmpty) return s2.length;
  if (s2.isEmpty) return s1.length;
  List<int> prev = List<int>.generate(s2.length + 1, (i) => i);
  List<int> curr = List<int>.filled(s2.length + 1, 0);
  for (int i = 0; i < s1.length; i++) {
    curr[0] = i + 1;
    for (int j = 0; j < s2.length; j++) {
      int cost = (s1[i] == s2[j]) ? 0 : 1;
      curr[j + 1] = [
        curr[j] + 1,
        prev[j + 1] + 1,
        prev[j] + cost,
      ].reduce((a, b) => a < b ? a : b);
    }
    prev = List<int>.from(curr);
  }
  return prev[s2.length];
}

bool _isValidSuffixChain(String text, Set<String> suffixes) {
  if (text.isEmpty) return true;
  for (int i = text.length; i >= 1; i--) {
    if (suffixes.contains(text.substring(0, i))) {
      if (_isValidSuffixChain(text.substring(i), suffixes)) return true;
    }
  }
  return false;
}

List<SimilarGroup> _findSimilarTask(List<Flashcard> cards) {
  final List<SimilarGroup> groups = [];
  final Set<int> processed = {};

  final List<Set<String>> wordSets = cards
      .map((c) => _tokenizeWords(c.front).toSet())
      .toList();

  for (int i = 0; i < cards.length; i++) {
    if (processed.contains(i)) continue;
    if (wordSets[i].length < 2)
      continue; // Skip very short phrases for global analysis

    final List<Flashcard> currentGroup = [cards[i]];
    processed.add(i);

    for (int j = i + 1; j < cards.length; j++) {
      if (processed.contains(j)) continue;

      final s1 = wordSets[i];
      final s2 = wordSets[j];
      if (s1.isEmpty || s2.isEmpty) continue;

      final intersection = s1.intersection(s2).length;
      final union = s1.length + s2.length - intersection;
      final similarity = intersection / union;

      // Require at least 2 matching words OR very high similarity for short sentences
      if ((intersection >= 2 && similarity >= 0.5) ||
          (intersection >= 1 && similarity >= 0.8)) {
        currentGroup.add(cards[j]);
        processed.add(j);
      }
    }

    if (currentGroup.length > 1) {
      String common = _findCommonWordPartAcrossGroup(currentGroup);

      // If no shared sequence, the grouping might be too loose.
      if (common.isEmpty) {
        common = _tokenizeWords(currentGroup[0].front).take(3).join(" ");
      }

      groups.add(
        SimilarGroup(cards: currentGroup, similarity: 1.0, commonPart: common),
      );
    }
  }

  return groups;
}

List<String> _tokenizeWords(String s) {
  return RegExp(
    r'[a-zA-Z\uAC00-\uD7A30-9]+',
  ).allMatches(s).map((m) => m.group(0)!).toList();
}

String _findLongestCommonWordSequence(String s1, String s2) {
  final w1 = _tokenizeWords(s1);
  final w2 = _tokenizeWords(s2);
  if (w1.isEmpty || w2.isEmpty) return "";

  // find longest common contiguous word subsequence
  int maxLen = 0;
  int endInW1 = 0;
  List<List<int>> table = List.generate(
    w1.length + 1,
    (_) => List<int>.filled(w2.length + 1, 0),
  );

  for (int i = 1; i <= w1.length; i++) {
    for (int j = 1; j <= w2.length; j++) {
      if (w1[i - 1].toLowerCase() == w2[j - 1].toLowerCase()) {
        table[i][j] = table[i - 1][j - 1] + 1;
        if (table[i][j] > maxLen) {
          maxLen = table[i][j];
          endInW1 = i;
        }
      }
    }
  }

  if (maxLen == 0) return "";
  return w1.sublist(endInW1 - maxLen, endInW1).join(" ");
}

String _findCommonWordPartAcrossGroup(List<Flashcard> cards) {
  if (cards.isEmpty) return "";
  if (cards.length == 1) return cards[0].front;

  String common = cards[0].front;
  for (int i = 1; i < cards.length; i++) {
    common = _findLongestCommonWordSequence(common, cards[i].front);
    if (common.isEmpty) break;
  }
  // Fallback to query or first few words if no contiguous sequence found
  return common;
}

List<SimilarGroup> _findSimilarByQueryTask(Map<String, dynamic> data) {
  final List<Flashcard> cards = data['cards'] as List<Flashcard>;
  final String query = (data['query'] as String);
  final String queryLower = query.toLowerCase();

  // 1. Strict Filtering: Only include if FRONT contains the query phrase
  // This ensures highlighting always works and the group name is present in all children.
  final List<Flashcard> matchedCards = [];

  for (final card in cards) {
    if (card.front.toLowerCase().contains(queryLower) ||
        card.back.toLowerCase().contains(queryLower)) {
      matchedCards.add(card);
    }
  }

  if (matchedCards.isEmpty) return [];

  return [
    SimilarGroup(cards: matchedCards, similarity: 1.0, commonPart: query),
  ];
}
