import re
import time
import os
import logging.config
import pandas as pd
import numpy as np
import json
import vertexai
import vertexai.preview.generative_models as generative_models

from vertexai.preview.generative_models import GenerativeModel
from datasets import DatasetDict
from datasets import Dataset

PROJECT_ID = os.getenv("PROJECT_ID", "gkebatchexpce3c8dcb")
# The bucket which contains the preprocessed data
BUCKET = os.getenv("BUCKET", "kh-finetune-ds")
REGION = os.getenv("REGION", "us-central1")
DATASET_INPUT = os.getenv("DATASET_INPUT_PATH", "flipkart_preprocessed_dataset")
DATASET_INPUT_FILE = os.getenv("DATASET_INPUT_FILE", "flipkart.csv")
DATASET_OUTPUT = os.getenv("DATASET_OUTPUT_PATH", "output")
MODEL_ID = os.getenv("PROMPT_MODEL_ID", "gemini-1.5-flash-001")

generation_config = {"max_output_tokens": 200, "temperature": 0.7}

safety_settings = {
    generative_models.HarmCategory.HARM_CATEGORY_HATE_SPEECH: generative_models.HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE,
    generative_models.HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT: generative_models.HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE,
    generative_models.HarmCategory.HARM_CATEGORY_SEXUALLY_EXPLICIT: generative_models.HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE,
    generative_models.HarmCategory.HARM_CATEGORY_HARASSMENT: generative_models.HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE,
}

num_questions = 3

vertexai.init(project=PROJECT_ID, location=REGION)
model = GenerativeModel(MODEL_ID)

logging.config.fileConfig("logging.conf")
logger = logging.getLogger("processing")
logger.debug(logger)


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
    output_string = ""  # Initialize empty string

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

    return output_string  # Return the final string


def generate_qa(context, category):
    prompt = f"Generate {num_questions} Search Queries in conversational tone and Answers for this product:\n{context}. Return the result without any formatting in a single line as Question : Answer ;"
    try:
        responses = model.generate_content(
            [prompt],
            generation_config=generation_config,
            safety_settings=safety_settings,
            stream=True,
        )
        qa = ""
        for response in responses:
            qa += response.text
        # print (qa)

        # Define the pattern to match questions and answers
        # pattern = r"Question : (.*?) : Answer : (.*?)(?=\nQuestion :|$)"  # $ for end of string

        # Extract questions and answers
        # matches = re.findall(pattern, qa, re.DOTALL)

        # Create a DataFrame
        temp_df = pd.DataFrame(columns=["Question", "Answer", "Context"])
        qa_list = qa.split(";")
        # Create a list to hold the data
        new_data = []

        for qa_item in qa_list:  # Iterate over the QA items
            q_a = qa_item.split(":")
            if len(q_a) == 2:
                ans = q_a[1].strip() + " \n " + extract_product_details(context)
                new_data.append(
                    [q_a[0].strip(), ans, f"Online shopping for {category}"]
                )  # Append as a list

        # Create the DataFrame after collecting all data
        temp_df = pd.DataFrame(new_data, columns=temp_df.columns)
        return temp_df
    except Exception as e:
        logger.error(e)
        return None


def generate_prompt(row):
    context = row["Context"]
    input_text = row["Question"]
    output_text = row["Answer"]
    return f"<start_of_turn>user\n Context:{context}\n{input_text}<end_of_turn> <start_of_turn>model\n{output_text}<end_of_turn>"


def data_prep(finetune_ds):
    result = pd.DataFrame()
    for context, category in zip(finetune_ds["context"], finetune_ds["c1_name"]):
        if context != np.nan:
            temp_df = generate_qa(context, category)
            if temp_df is not None:
                result = pd.concat([result, temp_df], ignore_index=True)
            time.sleep(
                1
            )  # Add a 1second delay to avoid API rate limiting (adjust as needed)
    # Now `result` contains all generated questions and answers
    return result


def train_validate_test_split(df):
    logger.info("Total Data Size:", len(df))
    train_size = int(0.8 * len(df))
    val_size = int(0.1 * len(df))
    train_df = df.sample(n=train_size, random_state=42)
    remaining_df = df.drop(train_df.index)
    val_df = remaining_df.sample(n=val_size, random_state=42)
    test_df = remaining_df.drop(val_df.index)
    logger.info(
        "Training data size:",
        len(train_df),
        "\n",
        "Validation data size:",
        len(val_df),
        "\n",
        "Test data size:",
        len(test_df),
    )
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


if __name__ == "__main__":

    # Prepare context for Gemini Flash's prompt
    df = prep_context()

    # Generate Q & A according
    res_df = data_prep(df)

    # Generate Prompts for Gemma IT model
    res_df["prompt"] = res_df.apply(generate_prompt, axis=1)

    # Upload prepared dataset into GCS
    train_validate_test_split(res_df)
