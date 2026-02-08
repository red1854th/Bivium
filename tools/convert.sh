#!/bin/bash
# gpt2ko → TFLite 변환 빠른 시작 스크립트

set -e

echo "=========================================="
echo "gpt2ko → TFLite 변환 시작"
echo "=========================================="

# 1. 의존성 설치
echo ""
echo "📦 [Step 1] 의존성 설치 중..."
pip install -q -r requirements.txt
echo "✓ 의존성 설치 완료"

# 2. 모델 디렉토리 준비
echo ""
echo "📁 [Step 2] 출력 디렉토리 준비 중..."
mkdir -p ../assets/models
echo "✓ 디렉토리 준비 완료"

# 3. 변환 실행
echo ""
echo "🔄 [Step 3] 모델 변환 중..."
echo "   (이 과정은 10-20분 소요될 수 있습니다)"
echo ""

DEVICE=${1:-cpu}
if command -v nvidia-smi &> /dev/null; then
    echo "💻 GPU (CUDA) 감지됨. GPU 사용 권장 (훨씬 빠름)"
    DEVICE=${1:-cuda}
fi

python gpt2ko_to_tflite.py \
  --model-name gpt2ko \
  --output-dir ../assets/models \
  --quantize int8 \
  --device $DEVICE

# 4. 결과 확인
echo ""
echo "=========================================="
echo "✅ 변환 완료!"
echo "=========================================="
echo ""
echo "생성된 파일:"
echo "  - assets/models/gpt2ko_spell.tflite"
echo "  - assets/models/tokenizer/"
echo ""
echo "다음 단계:"
echo "  1. pubspec.yaml에 tflite_flutter 추가"
echo "  2. lib/services/spellcheck_service.dart 작성"
echo "  3. study_page.dart에 서비스 통합"
echo ""
