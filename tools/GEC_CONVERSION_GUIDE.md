# Standard_Korean_GEC → Flutter 변환 가이드

`Soyoung97/gec_kr` (KoBART) 모델을 Flutter 앱에서 사용할 수 있도록 변환하고 통합하는 가이드입니다.

## 📋 변환 아키텍처

BART 모델은 Encoder-Decoder 구조이므로 모바일에서 효율적으로 실행하기 위해 다음과 같은 단계를 거칩니다:

1. **Python**: 모델을 로드하고 ONNX 및 PyTorch 형식으로 저장합니다.
2. **TFLite**: (선택사항) ONNX 모델을 TFLite로 최점화 변환합니다.
3. **Flutter**: `tflite_flutter` 또는 `onnxruntime_flutter`를 사용하여 온디바이스 추론을 수행합니다.

---

## 🔄 Step 1: 모델 변환 실행

준비된 스크립트를 사용하여 모델과 토크나이저를 추출합니다.

```powershell
# 가상환경 활성화 (필요시)
.\.venv\Scripts\activate

# 변환 스크립트 실행
python tools/convert_gec.py --output-dir assets/models/gec
```

### 생성되는 파일:
- `assets/models/gec/tokenizer/`: 토크나이저 어휘 및 설정
- `assets/models/gec/gec_kr_fp32.pt`: PyTorch 가중치 (참조용)
- `assets/models/gec/gec_kr.onnx`: ONNX 모델 (추론용)
- `assets/models/gec/config.json`: 모델 파라미터 정보

---

## 📱 Step 2: Flutter 통합

### 1. pubspec.yaml 설정

```yaml
dependencies:
  onnxruntime_flutter: ^0.1.0 # 또는 tflite_flutter
  
flutter:
  assets:
    - assets/models/gec/gec_kr.onnx
    - assets/models/gec/config.json
    - assets/models/gec/tokenizer/vocab.txt
```

### 2. GEC 서비스 구현 (`lib/services/gec_service.dart`)

```dart
import 'dart:convert';
import 'package:flutter/services.dart';

class KoreanGECService {
  bool _isInitialized = false;
  late Map<String, int> _vocab;
  
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // 토크나이저 로드
    final vocabContent = await rootBundle.loadString('assets/models/gec/tokenizer/vocab.txt');
    _vocab = {};
    vocabContent.split('\n').asMap().forEach((i, line) {
      if (line.trim().isNotEmpty) _vocab[line.trim()] = i;
    });
    
    _isInitialized = true;
  }
  
  Future<String> correctGrammar(String text) async {
    if (!_isInitialized) await initialize();
    
    // 여기에 ONNX Runtime 또는 TFLite 호출 로직 추가
    // 현재는 API 개발 전 단계이므로 플레이스홀더를 반환하거나
    // 기존 LanguageTool과 병행 사용하도록 설계되었습니다.
    return text; 
  }
}
```

---

## ⚙️ 상세 설정 및 문제 해결

### BART 모델의 특이점
BART 모델은 `generate()` 함수를 통해 문장을 생성합니다. TFLite에서 이 루프를 직접 구현하려면 Encoder와 Decoder를 분리해서 변환하는 것이 성능상 유리합니다.

### 메모리 관리
BART 모델은 약 500MB 정도의 메모리를 점유할 수 있으므로, 저사양 기기에서는 Isolate를 사용하여 백그라운드에서 실행하는 것을 권장합니다.

---

**문의 사항: `lib/gec_model/README.md`를 참고하세요.**
