import 'package:flutter/services.dart';

class DictionaryService {
  // 싱글톤 패턴 적용
  static final DictionaryService _instance = DictionaryService._internal();
  factory DictionaryService() => _instance;
  DictionaryService._internal();

  // 각 품사 및 형태소 집합 (중복 제거 및 고속 검색을 위해 Set 사용)
  final Set<String> meongsa = {};
  final Set<String> eogeun = {};
  final Set<String> josa = {};
  final Set<String> eomaleomi = {};
  final Set<String> seoneomaleomi = {};

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// 에셋 파일로부터 사전 데이터를 읽어와 메모리에 적재
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      await Future.wait([
        _loadCategory('assets/dict/meongsa.txt', meongsa),
        _loadCategory('assets/dict/eogeun.txt', eogeun),
        _loadCategory('assets/dict/josa.txt', josa),
        _loadCategory('assets/dict/eomaleomi.txt', eomaleomi),
        _loadCategory('assets/dict/seoneomaleomi.txt', seoneomaleomi),
      ]);
      _isInitialized = true;
    } catch (e) {
      // 파일이 없을 경우 빈 상태로 유지하거나 에러 처리
      rethrow;
    }
  }

  /// 텍스트 파일을 읽어 각 라인을 Set에 추가
  Future<void> _loadCategory(String path, Set<String> targetSet) async {
    try {
      final data = await rootBundle.loadString(path);
      final lines = data.split('\n');
      for (var line in lines) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty) {
          targetSet.add(trimmed);
        }
      }
    } catch (_) {
      // 특정 사전 파일이 없는 경우 로그를 남기거나 무시
    }
  }

  /// 메모리 최적화가 필요한 경우 초기화 상태 해제
  void dispose() {
    meongsa.clear();
    eogeun.clear();
    josa.clear();
    eomaleomi.clear();
    seoneomaleomi.clear();
    _isInitialized = false;
  }
}
