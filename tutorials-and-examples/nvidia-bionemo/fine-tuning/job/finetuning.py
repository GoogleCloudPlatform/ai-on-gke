#!/usr/bin/env python3
import os
import pandas as pd
import subprocess
import torch
import re
import warnings
import shutil
import json

from bionemo.core.data.load import load

warnings.filterwarnings("ignore")
warnings.simplefilter("ignore")

print("Setting WorkDir ...")
work_dir = "/workspace/bionemo2/esm2_finetune_tutorial"

if not os.path.exists(work_dir):
    os.makedirs(work_dir)
    print(f"Work dir: '{work_dir}' created.")

print("Downloading pre-trained model checkpoints ...")

checkpoint_path = load("esm2/650m:2.0")
print(checkpoint_path)

print("Entering regression ...")

def save_model_for_inference(checkpoint_dir, save_path):
    """Save the model in a format compatible with Hugging Face Transformers."""
    os.makedirs(save_path, exist_ok=True)
    
    print(f"Loading checkpoint from directory: {checkpoint_dir}")
    
    try:
        # Check the weights directory
        weights_dir = os.path.join(checkpoint_dir, "weights")
        if not os.path.exists(weights_dir):
            raise FileNotFoundError(f"Weights directory not found in {checkpoint_dir}")
            
        print(f"Contents of weights directory:")
        for file in os.listdir(weights_dir):
            print(f"- {file}")
            
        # Load weights from the weights directory
        weight_files = [f for f in os.listdir(weights_dir) if f.endswith('.pt')]
        if not weight_files:
            raise FileNotFoundError(f"No weight files found in {weights_dir}")
            
        model_file = os.path.join(weights_dir, weight_files[0])
        print(f"Loading model weights from: {model_file}")
        
        checkpoint = torch.load(model_file)
        print("Checkpoint loaded successfully")
        
        # Save the model weights
        if isinstance(checkpoint, dict):
            if 'state_dict' in checkpoint:
                state_dict = checkpoint['state_dict']
            else:
                state_dict = checkpoint
        else:
            state_dict = checkpoint
            
        torch.save(state_dict, os.path.join(save_path, "pytorch_model.bin"))
        print("Model weights saved successfully")
        
        # Save the ESM vocabulary file
        vocab_file = os.path.join(save_path, "vocab.txt")
        vocab = [
            "<pad>", "<mask>", "<cls>", "<sep>", "<unk>",
            "L", "A", "G", "V", "S", "E", "R", "T", "I", "D",
            "P", "K", "Q", "N", "F", "Y", "M", "H", "W", "C",
            "X", "B", "U", "Z", "O", ".", "-", "*"
        ]
        with open(vocab_file, "w") as f:
            f.write("\n".join(vocab))
        print("Vocabulary file saved successfully")
        
        # Create and save the config
        config = {
            "model_type": "esm",
            "architectures": ["ESMForSequenceClassification"],
            "hidden_size": 1280,
            "num_attention_heads": 20,
            "num_hidden_layers": 33,
            "vocab_size": 33,
            "max_position_embeddings": 1024,
            "pad_token_id": 1,
            "eos_token_id": 2,
            "hidden_act": "gelu",
            "attention_probs_dropout_prob": 0.0,
            "hidden_dropout_prob": 0.0,
            "initializer_range": 0.02,
            "layer_norm_eps": 1e-5,
            "position_embedding_type": "absolute"
        }
        
        with open(os.path.join(save_path, "config.json"), "w") as f:
            json.dump(config, f, indent=2)
        print("Config saved successfully")
        
        # Create tokenizer config with vocab file reference
        tokenizer_config = {
            "model_max_length": 1024,
            "padding_side": "right",
            "truncation_side": "right",
            "vocab_file": "vocab.txt",
            "do_lower_case": False,
            "special_tokens_map_file": None
        }
        
        with open(os.path.join(save_path, "tokenizer_config.json"), "w") as f:
            json.dump(tokenizer_config, f, indent=2)
        print("Tokenizer config saved successfully")
        
    except Exception as e:
        print(f"Error during model saving: {str(e)}")
        raise
def run_finetune_esm2():
    """Runs the finetune_esm2 command using subprocess."""
    command = ["python", "-m", "bionemo.esm2.model.finetune.train"]

    try:
        result = subprocess.run(command, check=True, capture_output=True, text=True)
        print("finetune_esm2 output:\n", result.stdout)
        match = re.search(r"checkpoint stored at (.*)", result.stdout)
        checkpoint_path = match.group(1).strip()
        print(f"Checkpoint path: {checkpoint_path}")
        return checkpoint_path

    except subprocess.CalledProcessError as e:
        print(f"finetune_esm2 failed with return code: {e.returncode}")
        print("stderr:\n", e.stderr)
        return None

def run_infer_esm2(work_dir, checkpoint_path, results_path):
    """Runs the infer_esm2 command using subprocess."""
    artificial_sequence_data = [
        "TLILGWSDKLGSLLNQLAIANESLGGGTIAVMAERDKEDMELDIGKMEFDFKGTSVI",
        "LYSGDHSTQGARFLRDLAENTGRAEYELLSLF",
        "GRFNVWLGGNESKIRQVLKAVKEIGVSPTLFAVYEKN",
        "DELTALGGLLHDIGKPVQRAGLYSGDHSTQGARFLRDLAENTGRAEYELLSLF",
        "KLGSLLNQLAIANESLGGGTIAVMAERDKEDMELDIGKMEFDFKGTSVI",
        "LFGAIGNAISAIHGQSAVEELVDAFVGGARISSAFPYSGDTYYLPKP",
        "LGGLLHDIGKPVQRAGLYSGDHSTQGARFLRDLAENTGRAEYELLSLF",
        "LYSGDHSTQGARFLRDLAENTGRAEYELLSLF",
        "ISAIHGQSAVEELVDAFVGGARISSAFPYSGDTYYLPKP",
        "SGSKASSDSQDANQCCTSCEDNAPATSYCVECSEPLCETCVEAHQRVKYTKDHTVRSTGPAKT",
    ]

    df = pd.DataFrame(artificial_sequence_data, columns=["sequences"])
    data_path = os.path.join(work_dir, "sequences.csv")
    df.to_csv(data_path, index=False)

    command = [
        "infer_esm2",
        "--checkpoint-path", checkpoint_path,
        "--data-path", data_path,
        "--results-path", results_path,
        "--config-class", "ESM2FineTuneSeqConfig",
    ]

    try:
        result = subprocess.run(command, check=True, capture_output=True, text=True)
        print("infer_esm2 output:\n", result.stdout)
        return True
    except subprocess.CalledProcessError as e:
        print(f"infer_esm2 failed with return code: {e.returncode}")
        print("stderr:\n", e.stderr)
        return False

checkpoint_path = run_finetune_esm2()
if checkpoint_path is not None:
    print("finetune_esm2 completed successfully.")
    results_path = work_dir

    print("Starting Inference ...")
    if run_infer_esm2(work_dir, checkpoint_path, results_path):
        print("Inference completed successfully.")
        
        # Save model in the format expected by the inference server
        inference_model_path = "/mnt/data/model"
        save_model_for_inference(checkpoint_path, inference_model_path)
        print(f"Model saved for inference at {inference_model_path}")

    else:
        print("Inference failed.")
else:
    print("finetune_esm2 failed.")