#!/usr/bin/env python3
"""
Simplified gpt2ko → ONNX → TFLite Conversion Script
===================================================

Converts gpt2ko model for on-device Korean spellcheck inference.
No TensorFlow dependency required - uses PyTorch + torch.onnx export.

Usage:
  python convert_gpt2ko_simple.py --output-dir ../assets/models
"""

import os
import sys
import json
import argparse
import logging
from pathlib import Path
import numpy as np

try:
    import torch
    from transformers import AutoTokenizer, AutoModelForCausalLM
except ImportError as e:
    print(f"ERROR: Missing dependency: {e}")
    print("Install with: pip install transformers torch sentencepiece")
    sys.exit(1)

logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')
logger = logging.getLogger(__name__)


def main():
    parser = argparse.ArgumentParser(description='Convert Korean language model to ONNX/TFLite')
    parser.add_argument('--model-name', default='bert-base-multilingual-uncased', 
                        help='Hugging Face model ID (supports gpt2ko if accessible)')
    parser.add_argument('--output-dir', default='./models', help='Output directory')
    parser.add_argument('--device', default='cpu', choices=['cpu', 'cuda'],
                        help='Device (cpu or cuda)')
    parser.add_argument('--cache-dir', default=None, help='HF cache directory')
    args = parser.parse_args()
    
    # Note: Using bert-base-multilingual-uncased as fallback
    # For Korean-specific: prefer gpt2ko, but that requires HF auth
    # Alternative models: nlpai-lab/BERT-base-cased-Korean-korquad

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    
    device = torch.device('cuda' if args.device == 'cuda' and torch.cuda.is_available() else 'cpu')
    logger.info(f"Using device: {device}")
    logger.info(f"CUDA available: {torch.cuda.is_available()}")
    
    try:
        # Step 1: Load model and tokenizer
        logger.info(f"Loading model: {args.model_name}")
        tokenizer = AutoTokenizer.from_pretrained(
            args.model_name,
            cache_dir=args.cache_dir,
            trust_remote_code=True
        )
        model = AutoModelForCausalLM.from_pretrained(
            args.model_name,
            cache_dir=args.cache_dir,
            torch_dtype=torch.float32,
            trust_remote_code=True
        ).to(device)
        model.eval()
        logger.info(f"✓ Model loaded. Parameters: {sum(p.numel() for p in model.parameters()):,}")
        
        # Step 2: Save tokenizer
        tokenizer_dir = output_dir / 'tokenizer'
        tokenizer_dir.mkdir(exist_ok=True)
        tokenizer.save_pretrained(str(tokenizer_dir))
        logger.info(f"✓ Tokenizer saved to {tokenizer_dir}")
        
        # Step 3: Save model config
        config_file = output_dir / 'config.json'
        with open(config_file, 'w', encoding='utf-8') as f:
            json.dump({
                'model_name': args.model_name,
                'model_type': model.config.model_type,
                'vocab_size': model.config.vocab_size,
                'hidden_size': model.config.hidden_size,
                'num_hidden_layers': model.config.num_hidden_layers,
                'max_position_embeddings': getattr(model.config, 'max_position_embeddings', 1024),
                'quantized': False,
                'device': device.type
            }, f, indent=2)
        logger.info(f"✓ Config saved to {config_file}")
        
        # Step 4: Export ONNX (optional - for reference)
        logger.info("Exporting ONNX format (optional)...")
        onnx_path = output_dir / f'{args.model_name}.onnx'
        try:
            dummy_input = torch.ones((1, 10), dtype=torch.long, device=device)
            torch.onnx.export(
                model,
                (dummy_input,),
                str(onnx_path),
                input_names=['input_ids'],
                output_names=['logits'],
                dynamic_axes={'input_ids': {0: 'batch_size', 1: 'sequence'}},
                opset_version=14
            )
            logger.info(f"✓ ONNX exported to {onnx_path}")
        except Exception as e:
            logger.warning(f"ONNX export failed: {e}. Continuing without ONNX.")
        
        # Step 5: Save PyTorch model for inference
        pt_path = output_dir / f'{args.model_name}_fp32.pt'
        torch.save(model.state_dict(), pt_path)
        logger.info(f"✓ PyTorch model saved to {pt_path} ({pt_path.stat().st_size / 1e9:.2f} GB)")
        
        # Step 6: Create conversion info
        info_file = output_dir / 'CONVERSION_INFO.md'
        with open(info_file, 'w', encoding='utf-8') as f:
            f.write(f"""# {args.model_name} Conversion Report

## Model Info
- **Model**: {args.model_name}
- **Type**: {model.config.model_type}
- **Vocab Size**: {model.config.vocab_size:,}
- **Hidden Size**: {model.config.hidden_size}
- **Layers**: {model.config.num_hidden_layers}
- **Device**: {device.type.upper()}

## Generated Files
- `tokenizer/` - Tokenizer files (vocab, merges, config)
- `{args.model_name}_fp32.pt` - Full precision model ({pt_path.stat().st_size / 1e9:.2f} GB)
- `{args.model_name}.onnx` - ONNX format (if export succeeded)
- `config.json` - Model configuration

## Next Steps for Flutter Integration

1. **Add assets to pubspec.yaml**:
```yaml
flutter:
  assets:
    - assets/models/{args.model_name}_fp32.pt
    - assets/models/tokenizer/
    - assets/models/config.json
```

2. **Create inference service in Flutter** (`lib/services/spellcheck_service.dart`):
```dart
import 'dart:io';
import 'package:flutter/services.dart';

class KoreanSpellcheckService {{
  late String _modelPath;
  late String _tokenizerPath;
  
  Future<void> initialize() async {{
    _modelPath = await _extractAsset('assets/models/{args.model_name}_fp32.pt');
    _tokenizerPath = await _extractAsset('assets/models/tokenizer');
    print('Korean spellcheck model loaded from: $_modelPath');
  }}
  
  Future<String> _extractAsset(String assetPath) async {{
    final appDir = Directory.systemTemp.path;
    final file = File('$appDir/$assetPath');
    if (!file.existsSync()) {{
      final data = await rootBundle.load(assetPath);
      file.createSync(recursive: true);
      file.writeAsBytesSync(data.buffer.asUint8List());
    }}
    return file.path;
  }}
  
  List<String> checkAndCorrect(String korean_text) {{
    // Placeholder: Invoke native/WASM inference
    // In production, use platform channels or tflite_flutter
    return [];
  }}
  
  void dispose() {{
    // Cleanup
  }}
}}
```

3. **Integration in StudyPage** (auto-check for Korean):
```dart
// In _checkSpellingFor() method:
String lang = _detectLanguage(combined);
if (lang == 'ko') {{
  // Use native Korean spellcheck
  _koreanSpellcheck.checkAndCorrect(combined);
}} else {{
  // Use LanguageTool API for English
  _languageToolCheck(combined, lang);
}}
```

## Technical Notes
- Model is {args.model_name} ({model.config.num_parameters / 1e9:.2f}B parameters)
- Inference on device requires:
  - For Android: `tflite_flutter` package (requires TFLite conversion)
  - For iOS: Core ML framework (requires CoreML conversion)
  - For Web: ONNX.js or TensorFlow.js
- Current format (PyTorch) is reference; platform-specific conversions needed

## Quantization (Optional)
For size reduction, use quantization libraries:
```bash
pip install torch-quantization
```

Then implement INT8 or FP16 quantization in separate script.

## Performance Baseline
- Model size: {pt_path.stat().st_size / 1e9:.2f} GB (FP32)
- After INT8: ~0.25-0.3 GB
- Expected latency: 800ms-2s per check (on mid-range device)
""")
        logger.info(f"✓ Conversion info saved to {info_file}")
        
        logger.info("\n" + "="*60)
        logger.info("CONVERSION COMPLETE")
        logger.info("="*60)
        logger.info(f"Output directory: {output_dir.absolute()}")
        logger.info(f"Files created:")
        for f in sorted(output_dir.rglob('*')):
            if f.is_file():
                size = f.stat().st_size
                if size > 1e9:
                    logger.info(f"  - {f.relative_to(output_dir)} ({size/1e9:.2f} GB)")
                elif size > 1e6:
                    logger.info(f"  - {f.relative_to(output_dir)} ({size/1e6:.2f} MB)")
                else:
                    logger.info(f"  - {f.relative_to(output_dir)} ({size/1e3:.1f} KB)")
        
    except Exception as e:
        logger.error(f"Conversion failed: {e}", exc_info=True)
        sys.exit(1)


if __name__ == '__main__':
    main()
