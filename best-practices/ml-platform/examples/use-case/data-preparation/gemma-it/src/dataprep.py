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
import json
import logging
import logging.config
import numpy as np
import os
import pandas as pd
import re
import signal
import sys
import tenacity
import time
import vertexai
import vertexai.preview.generative_models as generative_models

from datasets import Dataset, DatasetDict
from google.api_core.exceptions import InternalServerError, ResourceExhausted
from tenacity import retry, retry_if_exception_type, stop_after_attempt, wait_random_exponential
from vertexai.preview.generative_models import GenerativeModel

from custom_json_formatter import CustomJSONFormatter


PROJECT_ID = os.environ.get("PROJECT_ID")
# The bucket which contains the preprocessed data
BUCKET = os.environ.get("BUCKET")
REGION = os.environ.get("REGION")
DATASET_INPUT = os.environ.get("DATASET_INPUT_PATH")
DATASET_INPUT_FILE = os.environ.get("DATASET_INPUT_FILE")
DATASET_OUTPUT = os.environ.get("DATASET_OUTPUT_PATH")
MODEL_ID = os.environ.get("PROMPT_MODEL_ID")

generation_config = {"max_output_tokens": 200, "temperature": 0.7}

safety_settings = {
    generative_models.HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT: generative_models.HarmBlockThreshold.BLOCK_ONLY_HIGH,
    generative_models.HarmCategory.HARM_CATEGORY_HARASSMENT: generative_models.HarmBlockThreshold.BLOCK_ONLY_HIGH,
    generative_models.HarmCategory.HARM_CATEGORY_HATE_SPEECH: generative_models.HarmBlockThreshold.BLOCK_ONLY_HIGH,
    generative_models.HarmCategory.HARM_CATEGORY_SEXUALLY_EXPLICIT: generative_models.HarmBlockThreshold.BLOCK_ONLY_HIGH,
}

num_questions = 3

vertexai.init(project=PROJECT_ID, location=REGION)
model = GenerativeModel(MODEL_ID)

def filter_low_value_count_rows(df, column_name, min_count=10):
    """
    Removes rows from a DataFrame where the value count in the specified column is less than the given minimum count.

    Args:
        df: The Pandas DataFrame to filter.
        column_name: The name of the column to check value counts for.
        min_count: The minimum value count required for a row to be kept (default: 10).

    Returns:
        A new DataFrame with rows removed where value counts are below the threshold.
    """

    # Calculate value counts for the specified column
    value_counts = df[column_name].value_counts()

    # Filter values that meet the minimum count criteria
    filtered_values = value_counts[value_counts >= min_count].index

    # Create a new DataFrame keeping only rows with those values
    filtered_df = df[df[column_name].isin(filtered_values)]

    return filtered_df


def prep_context():
    preprocessed = pd.read_csv(f"gs://{BUCKET}/{DATASET_INPUT}/{DATASET_INPUT_FILE}")
    # renaming column name
    preprocessed.rename(
        columns={
            "uniq_id": "Id",
            "product_name": "Name",
            "description": "Description",
            "brand": "Brand",
            "attributes": "Specifications",
        },
        inplace=True,
    )
    df = preprocessed[
        [
            "Name",
            "Description",
            "Specifications",
            "Brand",
            "c0_name",
            "c1_name",
            "c2_name",
            "c3_name",
        ]
    ]

    # Filter only clothing products
    filtered_df = df[df["c0_name"] == "Clothing"]

    # Filter only Women, Men & Kids clothing products
    values_to_filter = ["Women's Clothing", "Men's Clothing", "Kids' Clothing"]
    clothing_filtered_df = filtered_df[filtered_df["c1_name"].isin(values_to_filter)]

    # Filter to keep rows where 'c2_name' has count >=10
    c2_filtered_df = filter_low_value_count_rows(
        clothing_filtered_df, "c2_name", min_count=10
    )

    # Filter to keep rows where 'c3_name' has count >=10
    c3_filtered_df = filter_low_value_count_rows(
        c2_filtered_df, "c3_name", min_count=10
    )

    # Data Format expected for finetuning: {"context": " ", "question": " ", "answer": " "}
    context_df = c3_filtered_df[["Name", "Description", "c1_name", "Specifications"]]
    finetune_ds = pd.DataFrame(columns=["context", "question", "answer"])
    finetune_ds["context"] = (
        "Product Name: "
        + context_df["Name"]
        + "<br> Product Category: "
        + context_df["c1_name"]
        + "<br> Attributes: "
        + context_df["Specifications"]
        + " <br> Description: "
        + context_df["Description"]
    )

    finetune_ds["c1_name"] = context_df["c1_name"]
    return finetune_ds


def extract_product_details(text):
    # Initialize empty string
    output_string = ""

    # Extract content before "Description:"
    match = re.search(r"(.*?)Description:", text, re.DOTALL)
    if match:
        content_before_description = match.group(1)

        # Remove <br> tags and "Product Category:" line
        cleaned_content = content_before_description.replace("<br>", "\n")
        lines = [
            line.strip()
            for line in cleaned_content.splitlines()
            if line.strip() and not line.startswith("Product Category:")
        ]

        # Extract and parse attributes
        match_attributes = re.search(
            r"Attributes:\s*(\{.*?\})", cleaned_content, re.DOTALL
        )
        if match_attributes:
            attributes_str = match_attributes.group(1)
            attributes = json.loads(attributes_str)

            # Append formatted output to output_string
            for line in lines:
                if not line.startswith("Attributes:"):
                    output_string += line + "\n"
            output_string += "Product Details:\n"
            for key, value in attributes.items():
                output_string += f"- {key}: {value}\n"

    # Return the final string
    return output_string

@retry(
    retry=(
        retry_if_exception_type(InternalServerError) | 
        retry_if_exception_type(ResourceExhausted)
    ),
    stop=stop_after_attempt(10), 
    wait=wait_random_exponential(exp_base=3, max=60, multiplier=1)
)
def generate_content(context):
    try:
        response = model.generate_content(
            [f"Generate {num_questions} Search Queries in conversational tone and Answers for this product:\n{context}. Return the result without any formatting in a single line as Question : Answer ;"],
            generation_config=generation_config,
            safety_settings=safety_settings,
        )
        response.text
    except InternalServerError as e:
        logger.warning(f"InternalServerError exception caught: {e}")
        raise
    except ResourceExhausted as e:
        logger.warning(e)
        raise
    except ValueError as e:
        logger.debug("ValueError exception caught")
        if response.candidates[0].finish_reason == generative_models.FinishReason.RECITATION:
            logger.warning(f"Recitation returned", extra={"context": context, "response": str(response)})
            return None
        elif response.candidates[0].finish_reason == generative_models.FinishReason.SAFETY:
            logger.warning(f"Blocked by safety settings", extra={"context": context, "response": str(response)})
            return None
        else:
            logger.error(f"Unhandled ValueError", extra={"context": context}, exc_info=True)
            raise
    except Exception as e:
        logger.error(f"Unhandled exception in generate_content: {type(e).__name__}", exc_info=True)
        raise

    return response.text


def generate_qa(context, category):
    try:
        qa = generate_content(context)
    except tenacity.RetryError as e:
        logger.error(f"Exception: {e}, failed to generate content for context: {context}")
        return None
    except Exception as e:
        logger.error(f"Unhandled exception from generate_content: {type(e).__name__}", exc_info=True)
        raise

    if qa == None:
        return None

    # Create a DataFrame
    temp_df = pd.DataFrame(columns=["Question", "Answer", "Context"])
    qa_list = qa.split(";")

    # Create a list to hold the data
    new_data = []

    # Iterate over the QA items
    for qa_item in qa_list:
        q_a = qa_item.split(":")
        if len(q_a) == 2:
            ans = q_a[1].strip() + " \n " + extract_product_details(context)
            # Append as the list
            new_data.append([q_a[0].strip(), ans, f"Online shopping for {category}"])

    # Create the DataFrame after collecting all data
    temp_df = pd.DataFrame(new_data, columns=temp_df.columns)

    return temp_df


def generate_prompt(row):
    return f"<start_of_turn>user\nContext:{row["Context"]}\n{row["Question"]}<end_of_turn><start_of_turn>model\n{row["Answer"]}<end_of_turn>"


def data_prep(finetune_ds):
    result = pd.DataFrame()
    for context, category in zip(finetune_ds["context"], finetune_ds["c1_name"]):
        if context != np.nan:
            temp_df = generate_qa(context, category)
            if temp_df is not None:
                result = pd.concat([result, temp_df], ignore_index=True)
                logger.info(f"Content generated", extra={"context": context})
    # Now `result` contains all generated questions and answers
    return result


def train_validate_test_split(df):
    logger.info(f"Total Data Size: {len(df)}")
    train_size = int(0.8 * len(df))
    val_size = int(0.1 * len(df))
    train_df = df.sample(n=train_size, random_state=42)
    remaining_df = df.drop(train_df.index)
    val_df = remaining_df.sample(n=val_size, random_state=42)
    test_df = remaining_df.drop(val_df.index)
    logger.info(f"Training data size: {len(train_df)}, Validation data size: {len(val_df)}, Test data size: {len(test_df)}")
    # Create DatasetDict with splits
    dataset = DatasetDict(
        {
            "train": Dataset.from_pandas(train_df),
            "validation": Dataset.from_pandas(val_df),
            "test": Dataset.from_pandas(test_df),
        }
    )
    dataset["train"].save_to_disk(f"gs://{BUCKET}/{DATASET_OUTPUT}/training/")
    dataset["validation"].save_to_disk(f"gs://{BUCKET}/{DATASET_OUTPUT}/validation/")
    dataset["test"].save_to_disk(f"gs://{BUCKET}/{DATASET_OUTPUT}/test/")


def graceful_shutdown(signal_number, stack_frame):
    signal_name = signal.Signals(signal_number).name

    logger.info(f"Received {signal_name}({signal_number}), shutting down...")
    #TODO: Add logic to handled checkpointing if required
    sys.exit(0)

if __name__ == "__main__":
    # Configure logging
    logging.config.fileConfig("logging.conf")

    logger = logging.getLogger("processing")

    if "LOG_LEVEL" in os.environ:
        new_log_level = os.environ["LOG_LEVEL"].upper()
        logger.info(
            f"Log level set to '{new_log_level}' via LOG_LEVEL environment variable"
        )
        logging.getLogger().setLevel(new_log_level)
        logger.setLevel(new_log_level)

    datasets.disable_progress_bar()

    logger.info("Configure signal handlers")
    signal.signal(signal.SIGINT, graceful_shutdown)
    signal.signal(signal.SIGTERM, graceful_shutdown)

    logger.info("Prepare context for Gemini Flash's prompt")
    df = prep_context()

    logger.info("Generate Q & A according")
    res_df = data_prep(df)

    logger.info("Generate Prompts for Gemma IT model")
    res_df["prompt"] = res_df.apply(generate_prompt, axis=1)

    logger.info("Upload prepared dataset into GCS")
    train_validate_test_split(res_df)
