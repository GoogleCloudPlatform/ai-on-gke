#!/usr/bin/env python3
import os
import pandas as pd
import subprocess
import torch
import re
import warnings
import shutil

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
        print("stderr:\n", e.stderr)  # Print stderr for debugging
        # Handle the error appropriately (e.g., raise it, log it, etc.)
        return False  # Or raise the exception

    return True


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

    # Save the DataFrame to a CSV file
    data_path = os.path.join(work_dir, "sequences.csv")
    df.to_csv(data_path, index=False)

    command = [
        "infer_esm2",
        "--checkpoint-path",
        checkpoint_path,
        "--data-path",
        data_path,
        "--results-path",
        results_path,
        "--config-class",
        "ESM2FineTuneSeqConfig",
    ]

    try:
        result = subprocess.run(command, check=True, capture_output=True, text=True)
        print("infer_esm2 output:\n", result.stdout)
        return True

    except subprocess.CalledProcessError as e:
        print(f"infer_esm2 failed with return code: {e.returncode}")
        print("stderr:\n", e.stderr)
        return False  # Or raise the exception

    return True


checkpoint_path = run_finetune_esm2()
if checkpoint_path is not None:
    print("finetune_esm2 completed successfully.")

    results_path = work_dir

    print("Starting Inference ...")
    if run_infer_esm2(work_dir, checkpoint_path, results_path):
        print("Inference completed successfully.")
        results_path = f"{results_path}/predictions__rank_0.pt"
        results = torch.load(results_path)
        print(f"Inference result: {results["regression_output"]}")

        filestore_path = "/mnt/data/esm2/results"
        os.makedirs(filestore_path, exist_ok=True)
        shutil.copy2(results_path, filestore_path)
        print(f"Result .pt file copied to {filestore_path}predictions__rank_0.pt")

    else:
        print("Inference failed.")

else:
    print("finetune_esm2 failed.")
