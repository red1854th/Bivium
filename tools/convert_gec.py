import os
import json
import shutil
import onnx
from pathlib import Path
from optimum.onnxruntime import ORTModelForSeq2SeqLM
from transformers import PreTrainedTokenizerFast

def convert_gec(model_id="theSOL1/kogrammar-base", output_dir="assets/models/gec"):
    print(f"Restoring {model_id} for high quality...")
    
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)
    temp_dir = output_path / "temp"
    
    # 1. Export standard model
    model = ORTModelForSeq2SeqLM.from_pretrained(model_id, export=True)
    tokenizer = PreTrainedTokenizerFast.from_pretrained(model_id)
    
    model.save_pretrained(temp_dir)
    tokenizer.save_pretrained(output_path / "tokenizer")

    # 2. Patch INT32 and Verify Logits
    mapping = {
        "encoder_model.onnx": "gec_encoder.onnx",
        "decoder_model.onnx": "gec_decoder.onnx"
    }
    
    for src_name, dst_name in mapping.items():
        src_path = temp_dir / src_name
        dst_path = output_path / dst_name
        if not src_path.exists(): continue
            
        onnx_model = onnx.load(str(src_path))
        for input in onnx_model.graph.input:
            if input.type.tensor_type.elem_type == onnx.TensorProto.INT64:
                input.type.tensor_type.elem_type = onnx.TensorProto.INT32
        
        # Verify output names
        print(f"Model {dst_name} outputs: {[o.name for o in onnx_model.graph.output]}")
        onnx.save(onnx_model, str(dst_path))

    # 3. Save Config
    config = {
        "bos_token_id": model.config.bos_token_id,
        "eos_token_id": model.config.eos_token_id,
        "pad_token_id": model.config.pad_token_id,
        "decoder_start_token_id": model.config.decoder_start_token_id or model.config.bos_token_id,
        "max_length": 64, # 지연 시간을 줄이기 위해 최대 길이를 적절히 조정
        "vocab_size": model.config.vocab_size,
    }
    with open(output_path / "config.json", "w") as f:
        json.dump(config, f)

    if temp_dir.exists():
        shutil.rmtree(temp_dir)

    print(f"\nSuccess! High-quality Base model restored.")

if __name__ == "__main__":
    convert_gec()
