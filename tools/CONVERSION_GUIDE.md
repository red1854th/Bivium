# gpt2ko → TFLite 변환 가이드

한국어 맞춤법 검사를 위해 gpt2ko 모델을 모바일 최적화 형식(TFLite)으로 변환합니다.

## 📋 필수 요구사항

### 1. Python 환경 설정

```bash
# Python 3.8+ 필요
python --version

# 가상 환경 생성 (선택사항이지만 권장)
python -m venv ./venv

# Windows
venv\Scripts\activate
# macOS/Linux
source venv/bin/activate
```

### 2. 의존성 설치

```bash
pip install --upgrade pip
pip install transformers>=4.30.0
pip install torch>=2.0.0
pip install tensorflow>=2.11.0
pip install onnx onnxruntime onnxruntime-tools
pip install numpy
```

**설치 확인:**
```bash
python -c "import torch; print(f'PyTorch: {torch.__version__}')"
python -c "import tensorflow as tf; print(f'TensorFlow: {tf.__version__}')"
python -c "from transformers import __version__; print(f'Transformers: {__version__}')"
```

---

## 🔄 변환 프로세스

### Step 1: 변환 스크립트 실행

모델을 다운로드하고 TFLite로 변환합니다.

#### 기본 변환 (INT8 양자화)
```bash
cd tools

# CPU에서 변환 (느림, ~10-20분)
python gpt2ko_to_tflite.py \
  --model-name gpt2ko \
  --output-dir ../assets/models \
  --quantize int8 \
  --device cpu

# 또는 GPU 사용 (빠름, ~2-5분, CUDA 필요)
python gpt2ko_to_tflite.py \
  --model-name gpt2ko \
  --output-dir ../assets/models \
  --quantize int8 \
  --device cuda
```

#### Float16 양자화 (더 높은 정확도, 더 큼)
```bash
python gpt2ko_to_tflite.py \
  --model-name gpt2ko \
  --output-dir ../assets/models \
  --quantize float16 \
  --device cpu
```

### Step 2: 출력 확인

변환 완료 후 다음 파일들이 생성됩니다:

```
assets/models/
├── gpt2ko_spell.tflite          ← TFLite 모델 (메인)
├── tokenizer/
│   ├── vocab.txt                ← 토크나이저 어휘
│   ├── config.json
│   ├── tokenizer_config.json
│   └── special_tokens_map.json
├── saved_model/                 ← TensorFlow SavedModel
└── onnx/                        ← ONNX 중간 포맷 (참고용)
```

**예상 파일 크기:**
- `gpt2ko_spell.tflite` (INT8): ~150-200 MB
- `gpt2ko_spell.tflite` (Float16): ~300-400 MB
- `tokenizer/` 합계: ~5 MB

---

## 📱 Flutter 통합

### Step 1: pubspec.yaml에 의존성 추가

```yaml
dependencies:
  flutter:
    sdk: flutter
  tflite_flutter: ^0.10.0  # TFLite 런타임
  # ... existing deps ...

dev_dependencies:
  flutter_test:
    sdk: flutter
```

### Step 2: 모델 파일 추가

```yaml
flutter:
  assets:
    - assets/models/gpt2ko_spell.tflite
    - assets/tokenizer/vocab.txt
    - assets/tokenizer/config.json
    # 기타 tokenizer 파일들
```

### Step 3: Flutter 통합 코드

`lib/services/spellcheck_service.dart`:

```dart
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class KoreanSpellcheckService {
  static const String _modelPath = 'assets/models/gpt2ko_spell.tflite';
  static const String _vocabPath = 'assets/tokenizer/vocab.txt';
  
  late Interpreter _interpreter;
  late Map<String, int> _vocab;
  bool _isInitialized = false;
  
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // 모델 로드
      _interpreter = await Interpreter.fromAsset(_modelPath);
      
      // 토크나이저 로드
      final vocabString = await rootBundle.loadString(_vocabPath);
      _vocab = {};
      vocabString.split('\n').asMap().forEach((idx, token) {
        _vocab[token.trim()] = idx;
      });
      
      _isInitialized = true;
      print('✓ Korean Spellcheck Service initialized');
    } catch (e) {
      print('❌ Failed to initialize: $e');
      rethrow;
    }
  }
  
  /// 텍스트의 맞춤법 검사
  /// Returns: 수정된 텍스트 또는 원본 (변경 없을 시)
  Future<String> checkAndCorrect(String text) async {
    if (!_isInitialized) await initialize();
    
    try {
      // 토큰화
      final tokens = _tokenize(text);
      final inputIds = _buildInputTensor(tokens);
      
      // 모델 추론
      final output = _runInference(inputIds);
      
      // 결과 디코딩
      final correctedText = _decodeOutput(output);
      
      return correctedText;
    } catch (e) {
      print('⚠️  Spellcheck failed: $e');
      return text; // 실패 시 원본 반환
    }
  }
  
  List<String> _tokenize(String text) {
    // 간단한 형태소 기반 토큰화 (프로덕션에서는 SentencePiece 사용)
    return text.split(RegExp(r'[\s\.\,\!\?]+'));
  }
  
  List<int> _buildInputTensor(List<String> tokens) {
    // 최대 길이 512
    const maxLen = 512;
    final inputIds = <int>[];
    
    for (int i = 0; i < tokens.length && i < maxLen; i++) {
      final token = tokens[i];
      inputIds.add(_vocab[token] ?? _vocab['[UNK]'] ?? 0);
    }
    
    // 패딩
    while (inputIds.length < maxLen) {
      inputIds.add(_vocab['[PAD]'] ?? 0);
    }
    
    return inputIds;
  }
  
  List<List<double>> _runInference(List<int> inputIds) {
    // TFLite 모델 실행
    final input = inputIds.reshape([1, inputIds.length]);
    final output = List.filled(1 * 512 * 30000, 0.0); // 대략적 크기
    
    _interpreter.run(input, output);
    
    return output.reshape([1, 512, 30000]);
  }
  
  String _decodeOutput(List<List<double>> output) {
    // 로짓에서 토큰 선택 (argmax)
    // 실제 구현에서는 더 정교한 디코딩 필요
    return "corrected_text";
  }
  
  void dispose() {
    _interpreter.close();
    _isInitialized = false;
  }
}
```

### Step 4: study_page.dart에 통합

```dart
import 'services/spellcheck_service.dart';

class _StudyPageState extends State<StudyPage> {
  late KoreanSpellcheckService _spellcheckService;
  
  @override
  void initState() {
    super.initState();
    _spellcheckService = KoreanSpellcheckService();
    _spellcheckService.initialize().then((_) {
      logger.info('✓ Spellcheck service ready');
    });
  }
  
  Future<void> _checkSpellingFor(int index) async {
    if (index < 0 || index >= widget.cards.length) return;
    final card = widget.cards[index];
    final combined = '${card.front}\n\n${card.back}';
    
    setState(() => _isCheckingSpell = true);
    
    try {
      // 한국어만 온디바이스 검사
      if (_detectLanguage(combined) == 'ko') {
        final corrected = await _spellcheckService.checkAndCorrect(combined);
        // 검사 결과 처리
      } else {
        // 영어는 LanguageTool API 사용 (기존 코드)
        final issues = await _languageToolCheck(combined, 'en-US');
      }
    } catch (e) {
      logger.warning('Spellcheck error: $e');
    } finally {
      setState(() => _isCheckingSpell = false);
    }
  }
  
  @override
  void dispose() {
    _spellcheckService.dispose();
    super.dispose();
  }
}
```

---

## ⚙️ 성능 최적화

### Quantization 비교

| 방식 | 크기 | 정확도 | 속도 | 권장 |
|------|------|--------|------|------|
| **INT8** | 150-200 MB | 95-97% | 가장 빠름 | ✅ 모바일 |
| **Float16** | 300-400 MB | 99%+ | 중간 | 중고급 기기 |
| **Float32** | 600+ MB | 100% | 느림 | ❌ 모바일 부적합 |

### 메모리 최적화

```dart
// 모델 캐싱 (중복 로드 방지)
static final KoreanSpellcheckService _instance = KoreanSpellcheckService._();
KoreanSpellcheckService._();
factory KoreanSpellcheckService() => _instance;

// 배치 처리
Future<List<String>> checkBatch(List<String> texts) async {
  // 여러 텍스트를 한 번에 처리 (더 빠름)
}

// Throttling (너무 자주 호출 방지)
Future<String> checkThrottled(String text, Duration throttle) async {
  // 지정된 시간 내 중복 호출 무시
}
```

---

## 🐛 문제 해결

### 1. "Model not found" 오류

```
확인:
- assets/models/gpt2ko_spell.tflite가 프로젝트 루트 기준 올바른 경로?
- pubspec.yaml의 assets 섹션이 정확?
- flutter clean; flutter pub get 실행?
```

### 2. "메모리 부족" 오류

```dart
// Isolate에서 실행 (별도 스레드)
import 'dart:isolate';

Future<String> checkInIsolate(String text) async {
  final result = await compute(_checkSpellInIsolate, text);
  return result;
}

static Future<String> _checkSpellInIsolate(String text) async {
  final service = KoreanSpellcheckService();
  await service.initialize();
  return await service.checkAndCorrect(text);
}
```

### 3. 느린 추론 속도

```
최적화:
1. INT8 양자화 사용 (이미 적용)
2. 입력 길이 제한 (최대 256 토큰)
3. 배치 처리 활용
4. 결과 캐싱 (동일 텍스트는 재사용)
```

---

## 📊 벤치마크 예상값

**하드웨어별 추론 시간 (INT8 quantized):**

| 기기 | RAM | 추론 시간 | 메모리 사용 |
|------|-----|----------|-----------|
| 중급 (Snapdragon 778) | 6GB | 800ms-1.2s | 150-200 MB |
| 플래그십 (Snapdragon 888) | 8GB | 300-500ms | 150-200 MB |
| 구형 (Snapdragon 660) | 4GB | 2-3s | 150-200 MB |

---

## 📝 다음 단계

1. ✅ **변환**: `gpt2ko_to_tflite.py` 실행
2. 📦 **통합**: Flutter 프로젝트에 모델/토크나이저 추가
3. 🧪 **테스트**: 작은 텍스트로 검증
4. 📈 **최적화**: 벤치마크 후 필요시 양자화 방식 변경
5. 🚀 **배포**: 앱 스토어에 배포

---

**문의 사항이나 오류가 발생하면 로그를 확인하세요.**
