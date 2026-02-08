#!/usr/bin/env python3
"""
gpt2ko (Korean Spell Correction Model) → TFLite Conversion Script
================================================================

This script converts a gpt2ko PyTorch model to TensorFlow SavedModel format,
then to TFLite with int8 quantization for on-device mobile inference.

Prerequisites:
  pip install transformers torch tensorflow tf-lite-support
  
Usage:
  python gpt2ko_to_tflite.py \
    --model-name "gpt2ko" \
    --output-dir "./models/tflite" \
    --quantize int8
"""

import os
import argparse
import logging
from pathlib import Path
import numpy as np

import torch
from transformers import AutoTokenizer, AutoModelForCausalLM

try:
    import tensorflow as tf
    from tensorflow.lite.python import lite
except ImportError:
    print("ERROR: TensorFlow not installed. Install with:")
    print("  pip install tensorflow>=2.11")
    exit(1)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class GPT2KoConverter:
    """Converter for gpt2ko model to TFLite."""
    
    def __init__(self, model_name="gpt2ko", device="cpu", output_dir="./models"):
        self.model_name = model_name
        self.device = torch.device(device)
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
        logger.info(f"Using device: {self.device}")
        
    def load_model(self):
        """Load gpt2ko model and tokenizer from HuggingFace."""
        logger.info(f"Loading model: {self.model_name}")
        try:
            self.tokenizer = AutoTokenizer.from_pretrained(self.model_name)
            self.model = AutoModelForCausalLM.from_pretrained(
                self.model_name,
                torch_dtype=torch.float32,
                device_map=str(self.device)
            )
            self.model.eval()
            logger.info("✓ Model and tokenizer loaded successfully")
        except Exception as e:
            logger.error(f"Failed to load model: {e}")
            raise
    
    def save_tokenizer(self):
        """Save tokenizer vocabulary and config for Flutter integration."""
        tokenizer_dir = self.output_dir / "tokenizer"
        tokenizer_dir.mkdir(parents=True, exist_ok=True)
        
        logger.info("Saving tokenizer files...")
        
        # Save vocab and special tokens
        self.tokenizer.save_pretrained(tokenizer_dir)
        
        # Create a simple mapping file for Flutter
        vocab_file = tokenizer_dir / "vocab.txt"
        with open(vocab_file, "w", encoding="utf-8") as f:
            for token, idx in sorted(self.tokenizer.get_vocab().items(), key=lambda x: x[1]):
                f.write(f"{token}\n")
        
        logger.info(f"✓ Tokenizer saved to {tokenizer_dir}")
        return tokenizer_dir
    
    def convert_to_savedmodel(self):
        """Convert PyTorch model to TensorFlow SavedModel format."""
        logger.info("Converting PyTorch → SavedModel...")
        
        # Create a simple wrapper for TF conversion
        class TextInput(tf.Module):
            def __init__(self, model, tokenizer):
                super().__init__()
                self.model = model
                self.tokenizer = tokenizer
            
            @tf.function(input_signature=[
                tf.TensorSpec(shape=[None], dtype=tf.string, name="text")
            ])
            def __call__(self, text):
                # Tokenize
                tokens = self.tokenizer(
                    text.numpy().decode('utf-8'),
                    return_tensors="pt",
                    max_length=512,
                    truncation=True,
                    padding="max_length"
                )
                
                input_ids = tf.constant(tokens['input_ids'].numpy(), dtype=tf.int32)
                attention_mask = tf.constant(tokens['attention_mask'].numpy(), dtype=tf.int32)
                
                # Forward pass
                with torch.no_grad():
                    outputs = self.model(
                        input_ids=torch.from_numpy(input_ids.numpy()),
                        attention_mask=torch.from_numpy(attention_mask.numpy())
                    )
                
                logits = tf.constant(outputs.logits.numpy(), dtype=tf.float32)
                return logits
        
        # For simplicity, we'll use a direct conversion approach
        # Convert model using Hugging Face to TF conversion
        try:
            from transformers import AutoModelForCausalLM
            
            logger.info("Converting model to TensorFlow...")
            tf_model = AutoModelForCausalLM.from_pretrained(
                self.model_name,
                from_pt=True
            )
            
            savedmodel_dir = self.output_dir / "saved_model"
            savedmodel_dir.mkdir(parents=True, exist_ok=True)
            
            tf_model.save_pretrained(savedmodel_dir)
            logger.info(f"✓ SavedModel saved to {savedmodel_dir}")
            
            return savedmodel_dir
        except Exception as e:
            logger.warning(f"HF TF conversion not available: {e}")
            logger.info("Using alternative: Exporting as ONNX first...")
            return self._convert_via_onnx()
    
    def _convert_via_onnx(self):
        """Alternative: Convert via ONNX as intermediate format."""
        logger.info("Converting via ONNX intermediate format...")
        
        try:
            from transformers import pipeline
            import onnx
            from onnxruntime.quantization import quantize_dynamic
        except ImportError:
            logger.error("ONNX tools not installed. Install with:")
            logger.error("  pip install onnx onnxruntime onnxruntime-tools")
            raise
        
        onnx_dir = self.output_dir / "onnx"
        onnx_dir.mkdir(parents=True, exist_ok=True)
        
        logger.info(f"Exporting to ONNX: {onnx_dir}")
        
        # Use transformers native ONNX export
        from transformers.onnx import main as onnx_export
        
        main_export = onnx_export.main_export(
            model_name_or_path=self.model_name,
            output=onnx_dir,
            task="text-generation-with-past"
        )
        
        logger.info(f"✓ ONNX model exported to {onnx_dir}")
        return onnx_dir
    
    def convert_to_tflite(self, quantization="int8"):
        """Convert SavedModel to TFLite with optional quantization."""
        logger.info(f"Converting SavedModel → TFLite (quantization: {quantization})...")
        
        savedmodel_dir = self.convert_to_savedmodel()
        
        try:
            converter = lite.TFLiteConverter.from_saved_model(str(savedmodel_dir))
            
            if quantization == "int8":
                logger.info("Applying INT8 quantization...")
                converter.optimizations = [tf.lite.Optimize.DEFAULT]
                converter.target_spec.supported_ops = [
                    tf.lite.OpsSet.TFLITE_BUILTINS_INT8,
                    tf.lite.OpsSet.TFLITE_BUILTINS
                ]
                converter.inference_input_type = tf.int8
                converter.inference_output_type = tf.int8
            elif quantization == "float16":
                logger.info("Applying FLOAT16 quantization...")
                converter.optimizations = [tf.lite.Optimize.DEFAULT]
                converter.target_spec.supported_types = [tf.float16]
            
            tflite_model = converter.convert()
            
            tflite_path = self.output_dir / "gpt2ko_spell.tflite"
            with open(tflite_path, "wb") as f:
                f.write(tflite_model)
            
            file_size_mb = tflite_path.stat().st_size / (1024 * 1024)
            logger.info(f"✓ TFLite model saved: {tflite_path} ({file_size_mb:.2f} MB)")
            
            return tflite_path
        
        except Exception as e:
            logger.error(f"TFLite conversion failed: {e}")
            raise
    
    def estimate_model_size(self):
        """Estimate model size and parameters."""
        total_params = sum(p.numel() for p in self.model.parameters())
        trainable_params = sum(p.numel() for p in self.model.parameters() if p.requires_grad)
        
        logger.info(f"\nModel Statistics:")
        logger.info(f"  Total parameters: {total_params:,}")
        logger.info(f"  Trainable parameters: {trainable_params:,}")
        logger.info(f"  Estimated FP32 size: ~{total_params * 4 / (1024**2):.2f} MB")
        logger.info(f"  Estimated INT8 size: ~{total_params * 1 / (1024**2):.2f} MB")
    
    def run(self, quantization="int8"):
        """Run complete conversion pipeline."""
        logger.info("=" * 60)
        logger.info("gpt2ko → TFLite Conversion Pipeline")
        logger.info("=" * 60)
        
        self.load_model()
        self.estimate_model_size()
        self.save_tokenizer()
        tflite_path = self.convert_to_tflite(quantization=quantization)
        
        logger.info("\n" + "=" * 60)
        logger.info("Conversion Complete!")
        logger.info("=" * 60)
        logger.info(f"\nOutput directory: {self.output_dir}")
        logger.info(f"  - TFLite model: gpt2ko_spell.tflite")
        logger.info(f"  - Tokenizer: tokenizer/")
        logger.info(f"  - SavedModel: saved_model/")
        
        logger.info("\nNext steps:")
        logger.info("  1. Copy gpt2ko_spell.tflite to Flutter assets/models/")
        logger.info("  2. Copy tokenizer/ files to Flutter assets/tokenizers/")
        logger.info("  3. Add tflite_flutter dependency to pubspec.yaml")
        logger.info("  4. Integrate with tflite_flutter in study_page.dart")


def main():
    parser = argparse.ArgumentParser(
        description="Convert gpt2ko to TFLite for on-device inference"
    )
    parser.add_argument(
        "--model-name",
        default="gpt2ko",
        help="HuggingFace model name (default: gpt2ko)"
    )
    parser.add_argument(
        "--output-dir",
        default="./models",
        help="Output directory for converted models"
    )
    parser.add_argument(
        "--quantize",
        choices=["int8", "float16", "none"],
        default="int8",
        help="Quantization method (default: int8)"
    )
    parser.add_argument(
        "--device",
        choices=["cpu", "cuda"],
        default="cpu",
        help="Device to use for conversion (default: cpu)"
    )
    
    args = parser.parse_args()
    
    converter = GPT2KoConverter(
        model_name=args.model_name,
        device=args.device,
        output_dir=args.output_dir
    )
    
    converter.run(quantization=args.quantize)


if __name__ == "__main__":
    main()
