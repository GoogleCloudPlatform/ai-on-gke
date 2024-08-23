#!/usr/bin/env python3
'''
Example usage:
   python3 upload_sharegpt.py --gcs_path="gs://$BUCKET_NAME/ShareGPT_V3_unfiltered_cleaned_split_filtered_prompts.txt"

upload_sharegpt.py executes the following steps:
1. downloads the original dataset "anon8231489123/ShareGPT_Vicuna_unfiltered" locally
2. filters out prompts from original dataset
3. uploads the filtered dataset to the given gcs bucket $BUCKET_NAME
4. deletes the local copy of "anon8231489123/ShareGPT_Vicuna_unfiltered"
'''
import argparse
import json
import logging
import os
import re
import time
import wget

from google.cloud import storage


logging.basicConfig(level=logging.INFO)


def main(gcs_path: str, overwrite: bool):
    logging.info("Validating gcs path provided.")
    # strip the "gs://", split into respective paths
    split_path = gcs_path[5:].split('/', 1)
    bucket_name = split_path[0]
    object_name = split_path[1]
    storage_client = storage.Client()
    bucket = storage_client.bucket(f"{bucket_name}")
    blob = bucket.blob(object_name)

    if not bucket.exists():
        raise ValueError(
            f"Cannot access gs://{bucket_name}, it may not exist or you may not have access to this bucket.")

    if blob.exists() and not overwrite:
        raise ValueError(
            f"{gcs_path} already exists, use --overwrite if okay to overwrite existing file.")

    logging.info(
        "Downloading anon8231489123/ShareGPT_Vicuna_unfiltered dataset locally.")
    start = time.time()

    url = "https://huggingface.co/datasets/anon8231489123/ShareGPT_Vicuna_unfiltered/resolve/main/ShareGPT_V3_unfiltered_cleaned_split.json"
    local_filename = wget.download(url)

    end = time.time()
    total_time = end - start
    logging.info(f"\nFinished downloading dataset in {total_time} seconds.")

    logging.info(f"Filtering dataset.")
    start = time.time()

    with open(local_filename) as f:
        dataset = json.load(f)
    # Filter out the conversations with less than 2 turns.
    dataset = [data for data in dataset if len(data["conversations"]) >= 2]
    # Only keep the first two turns of each conversation.
    dataset = [
        (data["conversations"][0]["value"], data["conversations"][1]["value"])
        for data in dataset
    ]
    prompts = [prompt.replace("\n", " ") for prompt, _ in dataset]

    end = time.time()
    total_time = end - start
    logging.info(
        f"Finished filtering prompts from dataset in {total_time} seconds.")

    logging.info(f"Uploading filtered dataset to {gcs_path}.")
    start = time.time()

    with blob.open("w") as f:
        for prompt in prompts:
            f.write(f'{prompt}\n')

    end = time.time()
    total_time = end - start
    logging.info(
        f"Finished uploading filtered dataset to {gcs_path} in {total_time} seconds.")

    os.remove(local_filename)
    logging.info(f"Deleted {local_filename}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description='Filter prompts from anon8231489123/ShareGPT_Vicuna_unfiltered and upload to gcs bucket.')
    parser.add_argument('--gcs_path', type=str,
                        help='gcs path to upload filtered prompts to.')
    parser.add_argument('--overwrite', default=False,
                        action=argparse.BooleanOptionalAction)
    args = parser.parse_args()
    gcs_uri_pattern = "^gs:\\/\\/[a-z0-9.\\-_]{3,63}\\/(.+\\/)*(.+)$"
    if not re.match(gcs_uri_pattern, args.gcs_path):
        raise ValueError(
            f"Invalid GCS path: {args.gcs_path}, expecting format \"gs://$BUCKET/$FILENAME\"")
    main(args.gcs_path, args.overwrite)
