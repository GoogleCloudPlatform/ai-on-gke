# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import datasets
import logging
import os
import signal
import sys
import torch
import transformers

from accelerate import Accelerator
from datasets import Dataset, load_dataset, load_from_disk
from peft import LoraConfig, PeftModel
from transformers import AutoModelForCausalLM, AutoTokenizer
from trl import DataCollatorForCompletionOnlyLM, SFTConfig, SFTTrainer

from custom_json_formatter import CustomJSONFormatter


def graceful_shutdown(signal_number, stack_frame):
    signal_name = signal.Signals(signal_number).name

    logger.info(f"Received {signal_name}({signal_number}), shutting down...")
    # TODO: Add logic to handled checkpointing if required
    sys.exit(0)


def formatting_prompts_func(example):
    output_texts = []
    for i in range(len(example["prompt"])):
        text = f"""{example["prompt"][i]}\n{EOS_TOKEN}"""
        output_texts.append(text)
    return {"prompts": output_texts}


if __name__ == "__main__":
    # Configure logging
    logger = logging.getLogger("finetune")
    LOG_LEVEL = os.environ.get("LOG_LEVEL", "INFO").upper()
    print(f"LOG_LEVEL: {LOG_LEVEL}")
    logger.setLevel(LOG_LEVEL)

    handler = logging.StreamHandler()
    handler.setFormatter(CustomJSONFormatter())
    handler.setLevel(LOG_LEVEL)
    logger.addHandler(handler)

    # For local testing you can enable logging to a file
    # file_handler = logging.FileHandler('fine_tuning.log')
    # file_handler.setFormatter(CustomJSONFormatter())
    # file_handler.setLevel(LOG_LEVEL)
    # logger.addHandler(file_handler)

    datasets.disable_progress_bar()
    transformers.utils.logging.disable_progress_bar()

    logger.info("Configure signal handlers")
    signal.signal(signal.SIGINT, graceful_shutdown)
    signal.signal(signal.SIGTERM, graceful_shutdown)

    if "MLFLOW_ENABLE" in os.environ and os.environ["MLFLOW_ENABLE"] == "true":
        import mlflow

        remote_server_uri = os.environ["MLFLOW_TRACKING_URI"]
        mlflow.set_tracking_uri(remote_server_uri)

        experiment = os.environ["EXPERIMENT"]
        mlflow.set_experiment(experiment)
        mlflow.autolog()

    accelerator = Accelerator()

    # The bucket which contains the training data
    training_data_bucket = os.environ["TRAINING_DATASET_BUCKET"]

    training_data_path = os.environ["TRAINING_DATASET_PATH"]

    # The model that you want to train from the Hugging Face hub
    model_name = os.environ["MODEL_NAME"]

    # Fine-tuned model name
    new_model = os.environ["NEW_MODEL"]

    # The root path of where the fine-tuned model will be saved
    save_model_path = os.environ["MODEL_PATH"]

    # Load tokenizer
    tokenizer = AutoTokenizer.from_pretrained(model_name, trust_remote_code=True)
    tokenizer.pad_token = tokenizer.eos_token
    tokenizer.padding_side = "right"  # Fix weird overflow issue with fp16 training

    EOS_TOKEN = tokenizer.eos_token

    training_dataset = load_from_disk(
        f"gs://{training_data_bucket}/{training_data_path}"
    )

    logger.info("Data Formatting Started")
    input_data = training_dataset.map(formatting_prompts_func, batched=True)
    logger.info("Data Formatting Completed")

    INPUT_OUTPUT_DELIMITER = "<start_of_turn>model"

    collator = DataCollatorForCompletionOnlyLM(
        INPUT_OUTPUT_DELIMITER, tokenizer=tokenizer
    )

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
    per_device_train_batch_size = int(os.getenv("TRAIN_BATCH_SIZE", "1"))

    # Batch size per GPU for evaluation
    per_device_eval_batch_size = 1

    # Number of update steps to accumulate the gradients for
    gradient_accumulation_steps = int(os.getenv("GRADIENT_ACCUMULATION_STEPS", "1"))

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
    logger.info("Loading base model started")
    model = AutoModelForCausalLM.from_pretrained(
        attn_implementation="eager",
        pretrained_model_name_or_path=model_name,
        torch_dtype=torch.bfloat16,
    )
    model.config.use_cache = False
    model.config.pretraining_tp = 1
    logger.info("Loading base model completed")

    # optimizer = torch.optim.AdamW(model.parameters(), lr=2e-4)

    logger.info("Configuring fine tuning started")
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
        bf16=bf16,
        dataset_kwargs={
            "add_special_tokens": False,  # We template with special tokens
            "append_concat_token": False,  # No need to add additional separator token
        },
        dataset_text_field="prompts",
        disable_tqdm=True,
        fp16=fp16,
        gradient_accumulation_steps=gradient_accumulation_steps,
        gradient_checkpointing=gradient_checkpointing,
        gradient_checkpointing_kwargs={"use_reentrant": False},
        group_by_length=group_by_length,
        log_on_each_node=False,
        logging_steps=logging_steps,
        learning_rate=learning_rate,
        lr_scheduler_type=lr_scheduler_type,
        max_grad_norm=max_grad_norm,
        max_seq_length=max_seq_length,
        max_steps=max_steps,
        num_train_epochs=num_train_epochs,
        optim=optim,
        output_dir=save_model_path,
        packing=packing,
        per_device_train_batch_size=per_device_train_batch_size,
        save_steps=save_steps,
        warmup_ratio=warmup_ratio,
        weight_decay=weight_decay,
    )
    logger.info("Configuring fine tuning completed")

    logger.info("Creating trainer started")
    trainer = SFTTrainer(
        args=training_arguments,
        data_collator=collator,
        model=model,
        peft_config=peft_config,
        tokenizer=tokenizer,
        train_dataset=input_data,
    )
    logger.info("Creating trainer completed")

    logger.info("Fine tuning started")
    trainer.train()
    logger.info("Fine tuning completed")

    if "MLFLOW_ENABLE" in os.environ and os.environ["MLFLOW_ENABLE"] == "true":
        mv = mlflow.register_model(
            model_uri=f"gs://{training_data_bucket}/{save_model_path}",
            name=new_model,
        )
        logger.info(f"Name: {mv.name}")
        logger.info(f"Version: {mv.version}")

    logger.info("Saving new model started")
    trainer.model.save_pretrained(new_model)
    logger.info("Saving new model completed")

    logger.info("Merging the new model with base model started")
    # Reload model in FP16 and merge it with LoRA weights
    base_model = AutoModelForCausalLM.from_pretrained(
        low_cpu_mem_usage=True,
        pretrained_model_name_or_path=model_name,
        return_dict=True,
        torch_dtype=torch.bfloat16,
    )
    model = PeftModel.from_pretrained(
        model=base_model,
        model_id=new_model,
    )
    model = model.merge_and_unload()
    logger.info("Merging the new model with base model completed")

    logger.info("Accelerate unwrap model started")
    unwrapped_model = accelerator.unwrap_model(model)
    logger.info("Accelerate unwrap model completed")

    logger.info("Save unwrapped model started")
    unwrapped_model.save_pretrained(
        is_main_process=accelerator.is_main_process,
        save_directory=save_model_path,
        save_function=accelerator.save,
    )
    logger.info("Save unwrapped model completed")

    logger.info("Save new tokenizer started")
    if accelerator.is_main_process:
        tokenizer.save_pretrained(save_model_path)
    logger.info("Save new tokenizer completed")

    logger.info("Script completed")
