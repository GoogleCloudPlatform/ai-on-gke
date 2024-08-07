import os
import torch
import logging.config
from accelerate import Accelerator

from datasets import load_dataset, Dataset
from transformers import (
    AutoModelForCausalLM,
    AutoTokenizer,
)
from peft import LoraConfig, PeftModel
from trl import SFTConfig
from trl import SFTTrainer, DataCollatorForCompletionOnlyLM
from datasets import load_from_disk

logging.config.fileConfig("logging.conf")
logger = logging.getLogger("finetune")
logger.debug(logger)

if "MLFLOW_ENABLE" in os.environ and os.environ.get("MLFLOW_ENABLE") == "true":
    import mlflow

    remote_server_uri = os.environ.get("MLFLOW_TRACKING_URI")
    mlflow.set_tracking_uri(remote_server_uri)

    experiment = os.environ.get("EXPERIMENT")

    mlflow.set_experiment(experiment)
    mlflow.autolog()

accelerator = Accelerator()

# The bucket which contains the training data
training_data_bucket = os.environ.get("TRAINING_DATASET_BUCKET")

training_data_path = os.environ.get("TRAINING_DATASET_PATH")

# The model that you want to train from the Hugging Face hub
model_name = os.environ.get("MODEL_NAME")

# Fine-tuned model name
new_model = os.environ.get("NEW_MODEL")

# The root path of where the fine-tuned model will be saved
save_model_path = os.environ.get("MODEL_PATH")

# Load tokenizer
tokenizer = AutoTokenizer.from_pretrained(model_name, trust_remote_code=True)
tokenizer.pad_token = tokenizer.eos_token
tokenizer.padding_side = "right"  # Fix weird overflow issue with fp16 training

EOS_TOKEN = tokenizer.eos_token


def formatting_prompts_func(example):
    output_texts = []
    for i in range(len(example["prompt"])):
        text = f"""{example["prompt"][i]}\n{EOS_TOKEN}"""
        output_texts.append(text)
    return {"prompts": output_texts}


training_dataset = load_from_disk(f"gs://{training_data_bucket}/{training_data_path}")

logger.info("Data Formatting Started")
input_data = training_dataset.map(formatting_prompts_func, batched=True)
logger.info("Data Formatting Completed")

INPUT_OUTPUT_DELIMITER = "<start_of_turn>model"

collator = DataCollatorForCompletionOnlyLM(INPUT_OUTPUT_DELIMITER, tokenizer=tokenizer)

################################################################################
# QLoRA parameters
################################################################################

# LoRA attention dimension
lora_r = int(os.getenv("LORA_R", "8"))

# Alpha parameter for LoRA scaling
lora_alpha = int(os.getenv("LORA_ALPHA", "16"))

# Dropout probability for LoRA layers
lora_dropout = float(os.getenv("LORA_DROPOUT", "0.1"))

################################################################################
# TrainingArguments parameters
################################################################################

# Output directory where the model predictions and checkpoints will be stored
# output_dir = "./results"

# Number of training epochs
num_train_epochs = int(os.getenv("EPOCHS", "1"))

# Enable fp16/bf16 training (set bf16 to True with an A100)
fp16 = False
bf16 = False

# Batch size per GPU for training
per_device_train_batch_size = 1

# Batch size per GPU for evaluation
per_device_eval_batch_size = 1

# Number of update steps to accumulate the gradients for
gradient_accumulation_steps = 1

# Enable gradient checkpointing
gradient_checkpointing = True

# Maximum gradient normal (gradient clipping)
max_grad_norm = float(os.getenv("MAX_GRAD_NORM", "0.3"))

# Initial learning rate (AdamW optimizer)
learning_rate = float(os.getenv("LEARNING_RATE", "2e-4"))

# Weight decay to apply to all layers except bias/LayerNorm weights
weight_decay = float(os.getenv("WEIGHT_DECAY", "0.001"))

# Optimizer to use
optim = "paged_adamw_32bit"

# Learning rate schedule
lr_scheduler_type = "cosine"

# Number of training steps (overrides num_train_epochs)
max_steps = -1

# Ratio of steps for a linear warmup (from 0 to learning rate)
warmup_ratio = float(os.getenv("WARMUP_RATIO", "0.03"))

# Group sequences into batches with same length
# Saves memory and speeds up training considerably
group_by_length = True

# Save checkpoint every X updates steps
save_steps = 0

# Log every X updates steps
logging_steps = 50

################################################################################
# SFT parameters
################################################################################

# Maximum sequence length to use
max_seq_length = int(os.getenv("MAX_SEQ_LENGTH", "512"))

# Pack multiple short examples in the same input sequence to increase efficiency
packing = False

# Load base model
model = AutoModelForCausalLM.from_pretrained(
    attn_implementation="eager",
    pretrained_model_name_or_path=model_name,
    torch_dtype=torch.bfloat16,
)
model.config.use_cache = False
model.config.pretraining_tp = 1

# optimizer = torch.optim.AdamW(model.parameters(), lr=2e-4)

# Load LoRA configuration
peft_config = LoraConfig(
    lora_alpha=lora_alpha,
    lora_dropout=lora_dropout,
    r=lora_r,
    bias="none",
    task_type="CAUSAL_LM",
    target_modules=[
        "q_proj",
        "k_proj",
        "v_proj",
        "o_proj",
        "gate_proj",
        "up_proj",
        "down_proj",
    ],
)

# Set training parameters
training_arguments = SFTConfig(
    dataset_kwargs={
        "add_special_tokens": False,  # We template with special tokens
        "append_concat_token": False,  # No need to add additional separator token
    },
    output_dir=save_model_path,
    num_train_epochs=num_train_epochs,
    per_device_train_batch_size=per_device_train_batch_size,
    gradient_accumulation_steps=gradient_accumulation_steps,
    gradient_checkpointing=gradient_checkpointing,
    gradient_checkpointing_kwargs={"use_reentrant": False},
    optim=optim,
    save_steps=save_steps,
    logging_steps=logging_steps,
    learning_rate=learning_rate,
    weight_decay=weight_decay,
    fp16=fp16,
    bf16=bf16,
    max_grad_norm=max_grad_norm,
    max_steps=max_steps,
    warmup_ratio=warmup_ratio,
    group_by_length=group_by_length,
    lr_scheduler_type=lr_scheduler_type,
    dataset_text_field="prompts",
    max_seq_length=max_seq_length,
    packing=packing,
)

trainer = SFTTrainer(
    model=model,
    args=training_arguments,
    train_dataset=input_data,
    tokenizer=tokenizer,
    peft_config=peft_config,
    data_collator=collator,
)

logger.info("Fine tuning started")
trainer.train()
logger.info("Fine tuning completed")

if "MLFLOW_ENABLE" in os.environ and os.environ.get("MLFLOW_ENABLE") == "true":
    mv = mlflow.register_model(
        model_uri=f"gs://{training_data_bucket}/{save_model_path}", name=new_model
    )
    logger.info(f"Name: {mv.name}")
    logger.info(f"Version: {mv.version}")

logger.info("Saving new model")
trainer.model.save_pretrained(new_model)

logger.info("Merging the model with base model")
# Reload model in FP16 and merge it with LoRA weights
base_model = AutoModelForCausalLM.from_pretrained(
    low_cpu_mem_usage=True,
    pretrained_model_name_or_path=model_name,
    return_dict=True,
    torch_dtype=torch.bfloat16,
)
model = PeftModel.from_pretrained(base_model, new_model)

model = model.merge_and_unload()

logger.info("Accelerate unwrap model")
unwrapped_model = accelerator.unwrap_model(model)

logger.info("Save new model")
unwrapped_model.save_pretrained(
    save_model_path,
    is_main_process=accelerator.is_main_process,
    save_function=accelerator.save,
)

logger.info("Save new tokenizer")
if accelerator.is_main_process:
    tokenizer.save_pretrained(save_model_path)

logger.info("### Completed ###")
