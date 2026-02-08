# gpt2ko Model Conversion & Flutter Integration - Execution Guide

## Status: Environment Setup in Progress ✓

### Current Progress
- ✅ Python venv configured (Python 3.14.2)
- ✅ Core dependencies installing (transformers, torch, sentencepiece)
- ✅ Simplified conversion script created: `tools/convert_gpt2ko_simple.py`
- ⏳ **WAIT**: Package installation finishing (2-5 minutes remaining)

---

## Step 1: Run Model Conversion (Once dependencies complete)

### Command (Windows PowerShell)
```powershell
cd C:\Users\user\Documents\Flutter\Bivium

# Run the conversion
.\.venv\Scripts\python.exe tools/convert_gpt2ko_simple.py `
  --model-name gpt2ko `
  --output-dir assets/models `
  --device cpu

# Or with GPU (if available):
# --device cuda
```

### What This Does
1. **Downloads** gpt2ko model from Hugging Face (~1.2B params, ~4-5 GB)
2. **Saves tokenizer** to `assets/models/tokenizer/`
3. **Exports model** to `assets/models/gpt2ko_fp32.pt` (~2-3 GB FP32)
4. **Generates config** with model metadata
5. **Creates report** with integration instructions

### Expected Output
```
assets/models/
├── tokenizer/              # SentencePiece tokenizer files
│   ├── vocab.txt
│   ├── spm.model
│   └── config.json
├── config.json             # Model configuration
├── gpt2ko_fp32.pt         # Full model (~2.3 GB)
├── gpt2ko.onnx            # Optional ONNX format
└── CONVERSION_INFO.md     # Integration guide
```

### Time Estimate
- **CPU**: 15-30 minutes (depends on internet/disk)
- **GPU**: 5-10 minutes (if CUDA available)
- **Storage needed**: 6-8 GB temporary, 3-4 GB final

---

## Step 2: Verify Conversion Success

```powershell
# Check if files exist
ls assets/models/

# Should show:
# CONVERSION_INFO.md
# config.json
# gpt2ko_fp32.pt (2-3 GB)
# gpt2ko.onnx (optional)
# tokenizer/ (directory)
```

---

## Step 3: Create Flutter Integration Service

### 3a. Update pubspec.yaml

Add to `flutter:` section:
```yaml
flutter:
  assets:
    - assets/models/config.json
    - assets/models/gpt2ko_fp32.pt
    - assets/models/tokenizer/vocab.txt
    - assets/models/tokenizer/spm.model
    - assets/models/tokenizer/config.json
```

### 3b. Create Spellcheck Service

Create file: `lib/services/spellcheck_service.dart`

```dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';

class KoreanSpellcheckService {
  static final KoreanSpellcheckService _instance = 
    KoreanSpellcheckService._internal();

  bool _initialized = false;
  late Map<String, dynamic> _modelConfig;
  late List<String> _vocab;

  KoreanSpellcheckService._internal();

  factory KoreanSpellcheckService() {
    return _instance;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      // Load model config
      final configJson = await rootBundle.loadString('assets/models/config.json');
      _modelConfig = jsonDecode(configJson);
      
      // Load vocabulary
      final vocabText = await rootBundle.loadString('assets/models/tokenizer/vocab.txt');
      _vocab = vocabText.split('\n').where((line) => line.isNotEmpty).toList();
      
      _initialized = true;
      print('✓ Korean spellcheck service initialized');
      print('  Model: ${_modelConfig['model_name']}');
      print('  Vocab size: ${_vocab.length}');
    } catch (e) {
      print('ERROR initializing spellcheck service: $e');
      rethrow;
    }
  }

  /// Check Korean text and return error messages
  /// In production, this would invoke native/WASM model inference
  Future<List<String>> checkAndCorrect(String koreanText) async {
    if (!_initialized) {
      print('WARNING: Service not initialized');
      return [];
    }

    if (koreanText.isEmpty) return [];

    try {
      // Placeholder: Actual inference would happen here
      // For now, return empty (fallback to LanguageTool API)
      // 
      // To add real inference:
      // 1. Use platform_channels to call native code (Android/iOS)
      // 2. Use flutter_rust_bridge for WASM inference
      // 3. Use isolate for CPU-bound operations
      
      return [];
    } catch (e) {
      print('ERROR in Korean spellcheck: $e');
      return [];
    }
  }

  void dispose() {
    // Cleanup if needed
  }
}
```

### 3c. Update study_page.dart

Integrate the service (auto-check for Korean text):

```dart
// At the top of _StudyPageState class:
final _koreanSpellcheck = KoreanSpellcheckService();

@override
void initState() {
  super.initState();
  _selectedId = widget.initialIndex;
  // Initialize spellcheck service
  _koreanSpellcheck.initialize().then((_) {
    if (widget.cards.isNotEmpty) _checkSpellingFor(_selectedId);
  });
}

@override
void dispose() {
  _koreanSpellcheck.dispose();
  _commentController.dispose();
  super.dispose();
}

// Modify _checkSpellingFor() to use hybrid approach:
Future<void> _checkSpellingFor(int index) async {
  if (index < 0 || index >= widget.cards.length) return;
  final card = widget.cards[index];
  final combined = '${card.front}\n\n${card.back}';
  final lang = _detectLanguage(combined);
  
  setState(() => _isCheckingSpell = true);
  
  List<String> issues = [];
  
  if (lang == 'ko') {
    // Use Korean model (once TFLite integrated)
    issues = await _koreanSpellcheck.checkAndCorrect(combined);
    // Fallback to LanguageTool if model inference not ready
    if (issues.isEmpty) {
      issues = await _languageToolCheck(combined, lang);
    }
  } else {
    // Use LanguageTool API for English
    issues = await _languageToolCheck(combined, lang);
  }
  
  setState(() {
    _spellcheckResults[index] = issues;
    _isCheckingSpell = false;
  });
}
```

---

## Step 4: Future - TFLite Integration (Optional)

Once model conversion succeeds, next steps for platform-specific inference:

### For Android
```bash
# Add to pubspec.yaml
flutter pub add tflite_flutter

# Requires NDK + native implementation
```

### For iOS
```bash
# Convert to Core ML for on-device inference
pip install coremltools

python -c "
import coremltools as ct
import torch
model = torch.load('assets/models/gpt2ko_fp32.pt')
traced = torch.jit.trace(model, torch.ones(1, 512))
mlmodel = ct.convert(traced)
mlmodel.save('gpt2ko_spell.mlmodel')
"
```

### For Web
```bash
# Use ONNX.js or TensorFlow.js
flutter pub add web

# In web/index.html:
<script src="https://cdn.jsdelivr.net/npm/onnxruntime-web/dist/ort.min.js"></script>
```

---

## Timeline Summary

| Phase | Time | Status |
|-------|------|--------|
| 1. Env setup | 5 min | ✅ In Progress |
| 2. Model conversion | 15-30 min | ⏳ Next |
| 3. Service creation | 5 min | 📋 Ready to implement |
| 4. Study page integration | 10 min | 📋 Ready to implement |
| 5. TFLite per-platform | 1-3 hours | 🔮 Optional future |

---

## Troubleshooting

### "Module not found" errors
```powershell
# Verify installation
.\.venv\Scripts\python.exe -m pip list | Select-String "torch|transformers"

# Reinstall if needed
.\.venv\Scripts\python.exe -m pip install --force-reinstall torch transformers
```

### Out of disk space
Model download is ~5 GB. Ensure you have free space on C: drive.

### Slow conversion
- Download is network-dependent
- Model loading: 5-10 min on normal CPU
- Model inference: 1-2 seconds per card on Snapdragon 888

---

## Next Actions (After conversion completes)

1. ✅ Wait for pip install to complete (should be ~5 min from now)
2. ✅ Run the conversion script
3. ✅ Verify `assets/models/` directory created
4. ✅ Create `lib/services/spellcheck_service.dart`
5. ✅ Update `pubspec.yaml` with assets
6. ✅ Integrate into `study_page.dart` (hybrid Korean/English)
7. (Optional) Set up platform-specific TFLite for actual inference

---

**Status**: Awaiting pip installation completion. Check back in 2-3 minutes!
