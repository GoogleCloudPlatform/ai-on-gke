# Make sure to run the script with the following envs:
#   PJRT_DEVICE=TPU XLA_USE_SPMD=1
import os
import torch
import torch_xla

import torch_xla.core.xla_model as xm

from datasets import load_dataset
from peft import LoraConfig, PeftModel
from transformers import AutoTokenizer, AutoModelForCausalLM, TrainingArguments
from trl import SFTTrainer

import transformers

print("TORCH: ", torch.__version__)
print("TRANSFORMERS: ", transformers.__version__)

# Set up TPU device.
device = xm.xla_device()
model_id = os.getenv("MODEL_ID","google/gemma-7b")
new_model_id = os.getenv("NEW_MODEL_ID","gemma-7b-sql-context")

job_index = os.getenv("JOB_COMPLETION_INDEX")

print("### LOAD TOKENIZER ###")
# Load the pretrained model and tokenizer.
tokenizer = AutoTokenizer.from_pretrained(model_id)
tokenizer.pad_token = tokenizer.eos_token
tokenizer.padding_side = "right" # Fix weird overflow issue with fp16 training


print("### LOAD MODEL ###")
model = AutoModelForCausalLM.from_pretrained(model_id, torch_dtype=torch.bfloat16)

print(model)

# Set up PEFT LoRA for fine-tuning.
lora_config = LoraConfig(
    r=8,
    lora_alpha = 16,
    lora_dropout = 0.1,
    bias="none",
    target_modules=["q_proj", "v_proj"],
    task_type="CAUSAL_LM",
)

print("### LOAD DATASET ###")

limit = int(os.getenv("LIMIT", "5000"))

dataset_name = "b-mc2/sql-create-context"
# Load the dataset and format it for training.
dataset = load_dataset(dataset_name, split="train")
dataset = dataset.shuffle(seed=42).select(range(limit))

def transform(data):
    question = data['question']
    context = data['context']
    answer = data['answer']
    template = "Question: {question}\nContext: {context}\nAnswer: {answer}"
    return {'text': template.format(question=question, context=context, answer=answer)}

print("### TRANSFORM DATASET ###")
dataset = dataset.map(transform)


max_seq_length = 512

# Set up the FSDP config. To enable FSDP via SPMD, set xla_fsdp_v2 to True.
fsdp_config = {"fsdp_transformer_layer_cls_to_wrap": [
        "GemmaDecoderLayer"
    ],
    "xla": True,
    "xla_fsdp_v2": True,
    "xla_fsdp_grad_ckpt": True}

print("### CREATE SFTTRAINER###")
# Finally, set up the trainer and train the model.
trainer = SFTTrainer(
    model=model,
    train_dataset=dataset,
    args=TrainingArguments(
        per_device_train_batch_size=64,  # This is actually the global batch size for SPMD.
        num_train_epochs=1,
        max_steps=-1,
        output_dir="./output",
        optim="adafactor",
        logging_steps=1,
        dataloader_drop_last = True,  # Required for SPMD.
        fsdp="full_shard",
        fsdp_config=fsdp_config,
    ),
    peft_config=lora_config,
    dataset_text_field="text",
    max_seq_length=max_seq_length,
    packing=True,
)


print("### STARTING TRAINING ###")
trainer.train()
print("### TRAINING ENDED ###")


print("JOB INDEX: ", job_index)

print("### COMBINE AND MODEL WEIGHT ###")
trainer.save_model(new_model_id)
# Reload model in FP16 and merge it with LoRA weights
base_model = AutoModelForCausalLM.from_pretrained(
    model_id,
    low_cpu_mem_usage=True,
    return_dict=True,
    torch_dtype=torch.bfloat16,
)

model = PeftModel.from_pretrained(base_model, new_model_id)
model = model.merge_and_unload()

print("### DONE MERGING ###")

if job_index == "0":
    print("### UPLOAD MODEL TO HUGGING FACE ###")
    # model.config.to_json_file("adapter_config.json")
    print(model)
    os.listdir(new_model_id)
    model.push_to_hub(repo_id=new_model_id)
    tokenizer.push_to_hub(repo_id=new_model_id)
else:
    print("Model will be uploaded by job 0")
