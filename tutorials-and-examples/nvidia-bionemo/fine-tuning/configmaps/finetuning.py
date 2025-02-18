#!/usr/bin/env python3
import sys
import os
import shutil
import pandas as pd
import subprocess
import torch

import warnings

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

data = [(seq, len(seq) / 100.0) for seq in artificial_sequence_data]

# Save the DataFrame to a CSV file
df = pd.DataFrame(data, columns=["sequences", "labels"])
data_path = os.path.join(work_dir, "regression_data.csv")
df.to_csv(data_path, index=False)


def run_finetune_esm2(checkpoint_path, data_path, work_dir):
    """Runs the finetune_esm2 command using subprocess."""

    command = [
        "finetune_esm2",  # Note: this must be in your system's PATH
        "--restore-from-checkpoint-path",
        checkpoint_path,
        "--train-data-path",
        data_path,
        "--valid-data-path",
        data_path,
        "--config-class",
        "ESM2FineTuneSeqConfig",
        "--dataset-class",
        "InMemorySingleValueDataset",
        "--task-type",
        "regression",
        "--experiment-name",
        "regression",
        "--num-steps",
        "50",
        "--num-gpus",
        "1",
        "--val-check-interval",
        "10",
        "--log-every-n-steps",
        "10",
        "--encoder-frozen",
        "--lr",
        "5e-3",
        "--lr-multiplier",
        "1e2",
        "--scale-lr-layer",
        "regression_head",
        "--result-dir",
        work_dir,
        "--micro-batch-size",
        "2",
        "--num-gpus",
        "1",  # Repeated – you might want to remove one
        "--precision",
        "bf16-mixed",
    ]

    try:
        result = subprocess.run(
            command, check=True, capture_output=True, text=True
        )  # Capture stdout/stderr
        print("finetune_esm2 output:\n", result.stdout)

    except subprocess.CalledProcessError as e:
        print(f"finetune_esm2 failed with return code: {e.returncode}")
        print("stderr:\n", e.stderr)  # Print stderr for debugging
        # Handle the error appropriately (e.g., raise it, log it, etc.)
        return False  # Or raise the exception

    return True


def run_infer_esm2(checkpoint_path, data_path, results_path):
    """Runs the infer_esm2 command using subprocess."""

    command = [
        "infer_esm2",  # Must be in your system's PATH
        "--checkpoint-path",
        checkpoint_path,
        "--config-class",
        "ESM2FineTuneSeqConfig",
        "--data-path",
        data_path,
        "--results-path",
        results_path,
        "--micro-batch-size",
        "3",
        "--num-gpus",
        "1",
        "--precision",
        "bf16-mixed",
        "--include-embeddings",
        "--include-input-ids",
    ]

    try:
        result = subprocess.run(command, check=True, capture_output=True, text=True)
        print("infer_esm2 output:\n", result.stdout)

    except subprocess.CalledProcessError as e:
        print(f"infer_esm2 failed with return code: {e.returncode}")
        print("stderr:\n", e.stderr)
        return False  # Or raise the exception

    return True


if run_finetune_esm2(checkpoint_path, data_path, work_dir):
    print("finetune_esm2 completed successfully.")
else:
    # Handle the error condition if the command failed
    pass  # Or take other appropriate action

# Create a DataFrame
df = pd.DataFrame(artificial_sequence_data, columns=["sequences"])

# Save the DataFrame to a CSV file
data_path = os.path.join(work_dir, "sequences.csv")
df.to_csv(data_path, index=False)

checkpoint_path = f"{work_dir}/regression/dev/checkpoints/checkpoint-step=49-consumed_samples=100.0-last"
results_path = f"{work_dir}/token_level_classification/infer/"

if run_infer_esm2(checkpoint_path, data_path, results_path):
    print("infer_esm2 completed successfully.")
else:
    print("infer_esm2 failed.")  # Or handle the error as needed


results = torch.load(f"{results_path}predictions__rank_0.pt")

for key, val in results.items():
    if val is not None:
        print(f"{key}\t{val.shape}")
