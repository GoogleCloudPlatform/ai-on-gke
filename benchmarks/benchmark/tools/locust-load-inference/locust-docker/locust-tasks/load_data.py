#!/usr/bin/env python

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

import argparse
import logging
import random
import re
import time

from google.cloud import storage
from transformers import AutoTokenizer, PreTrainedTokenizerBase


logging.basicConfig(level=logging.INFO)


def load_test_prompts(gcs_path: str, tokenizer: PreTrainedTokenizerBase, max_prompt_len: int):
    # strip the "gs://", split into respective paths
    split_path = gcs_path[5:].split('/', 1)
    bucket_name = split_path[0]
    object_name = split_path[1]
    storage_client = storage.Client()
    bucket = storage_client.bucket(bucket_name)
    blob = bucket.blob(object_name)

    if not bucket.exists():
        raise ValueError(
            f"Cannot access gs://{bucket_name}, it may not exist or you may not have access to this bucket.")
    if not blob.exists():
        raise ValueError(
            f"Cannot access {gcs_path}, it may not exist or you may not have access to this object.")

    test_data = []
    start = time.time()
    with blob.open("r") as f:
        for prompt in f:
            prompt_token_ids = tokenizer(prompt).input_ids
            prompt_len = len(prompt_token_ids)
            if prompt_len < 4:
                # Prune too short sequences.
                # This is because TGI causes errors when the input or output length
                # is too short.
                continue
            if prompt_len > max_prompt_len:
                # Prune too long sequences.
                continue
            test_data.append(prompt)
    end = time.time()
    total_time = end - start
    logging.info(f"Filtered test prompts after {total_time} seconds.")
    return test_data


def main(gcs_path: str, tokenizer_name: str, max_prompt_len: int, max_num_prompts: int):
    global test_data
    global tokenizer

    try:
        tokenizer = AutoTokenizer.from_pretrained(
            tokenizer_name)
    except Exception as e:
        logging.error(f"Failed to create tokenizer: {e}")
    logging.info(f"Successfully loaded tokenizer {tokenizer_name}.")

    logging.info(f"Loading test prompts from {gcs_path}.")
    try:
        test_data = load_test_prompts(gcs_path, tokenizer, max_prompt_len)
    except Exception as e:
        logging.error(f"Failed to load test data from {gcs_path}: {e}")
    logging.info(f"Loaded {len(test_data)} test prompts from {gcs_path}.")

    if max_num_prompts < len(test_data):
        test_data = random.sample(test_data, max_num_prompts)

    # Rewrite filtered dataset to tmp file.
    with open("locust-tasks/filtered_prompts.txt", "x") as f:
        for prompt in test_data:
            strippedPrompt = prompt.replace("\n", " ")
            f.write(f'{strippedPrompt}\n')
    logging.info(
        f"Wrote {len(test_data)} test prompts to locust-tasks/filtered_prompts.txt")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description='Filter and prepare dataset for Locust benchmarking test.')
    parser.add_argument('--gcs_path', type=str,
                        help='gcs path to download prompts from.')
    parser.add_argument('--max_prompt_len', type=int,
                        help='Maximum number of input tokens. Used as max filter on dataset prompts.', default=1024)
    parser.add_argument('--max_num_prompts', type=int,
                        help='maximum number of prompts to keep for dataset.', default=100)
    parser.add_argument('--tokenizer', type=str,
                        help='Name or path of the tokenizer.')
    args = parser.parse_args()
    gcs_uri_pattern = "^gs:\/\/[a-z0-9.\-_]{3,63}\/(.+\/)*(.+)$"
    if not re.match(gcs_uri_pattern, args.gcs_path):
        raise ValueError(
            f"Invalid GCS path: {args.gcs_path}, expecting format \"gs://$BUCKET/$FILENAME\"")
    main(args.gcs_path, args.tokenizer, args.max_prompt_len, args.max_num_prompts)
