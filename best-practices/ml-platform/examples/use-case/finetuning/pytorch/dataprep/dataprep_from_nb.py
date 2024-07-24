# ---
# jupyter:
#   jupytext:
#     formats: ipynb,py:percent
#     text_representation:
#       extension: .py
#       format_name: percent
#       format_version: '1.3'
#       jupytext_version: 1.16.2
#   kernelspec:
#     display_name: Python 3
#     name: python3
# ---

import os
BUCKET = os.environ['BUCKET']
PROJECT_ID = os.environ['PROJECT_ID']

# %% [markdown] id="6TWzj1gblrbS"
# ### Authenticate
#
# If you are using Colab, you will need to authenticate yourself first. The next cell will check if you are currently using Colab, and will start the authentication process.

# %% id="7i-ZEzXfDYz0"
import sys
if 'google.colab' in sys.modules:
    from google.colab import auth as google_auth
    google_auth.authenticate_user()

# %% colab={"base_uri": "https://localhost:8080/"} id="tQL63h--NMeR" outputId="2d40b7cb-478b-46f0-fde0-67978b0d5a9d"
# !which python

# %% colab={"base_uri": "https://localhost:8080/"} id="tJnCtVhnN1_G" outputId="57f882c5-071f-42c9-9a20-dacdf1af66e5"
# !python --version

# %% [markdown] id="RGo7Ow4Ok6_o"
# ## Installation & Configurations

# %% id="e-8lD0s-duaH" colab={"base_uri": "https://localhost:8080/"} outputId="31a0a574-a376-4350-e109-68d34bec0cc6"
# !pip install google-cloud-storage

# %% id="-g76eZuYOzgK" colab={"base_uri": "https://localhost:8080/"} outputId="fc38f0f4-1525-4335-8064-14604ab10554"
# !python -m pip install openpyxl

# %% [markdown] id="eYfQrGE9lGul"
# # Dataset
#
# [This](https://www.kaggle.com/datasets/PromptCloudHQ/flipkart-products) is a pre-crawled dataset, taken as subset of a bigger dataset (more than 5.8 million products) that was created by extracting data from [Flipkart](https://www.flipkart.com/), a leading Indian eCommerce store.
#

# %% id="moISnRwvCEUd"
import pandas as pd
full_ds = pd.read_csv('gs://'+BUCKET+'/flipkart_com-ecommerce_sample.csv')

# %% colab={"base_uri": "https://localhost:8080/", "height": 486} id="3QFeCMTq10V5" outputId="7a93d51f-361d-42d2-819d-154b1175934a"
full_ds.head()

# %% colab={"base_uri": "https://localhost:8080/"} id="-s7vegKVUSls" outputId="ebe155b4-2ba0-470a-f412-01dbe57a6208"
full_ds.info()

# %% id="X7cmzXyz1yJ3"
df = full_ds[['uniq_id','product_name','description','brand','product_category_tree','product_specifications','image']]

# %% colab={"base_uri": "https://localhost:8080/"} id="vGdHYiWCY23I" outputId="03856347-41c4-4e38-bf9d-3ea9e29c2d04"
# check the values of each row for each column
n = df.nunique(axis=0)
print("No.of.unique values in each column : \n", n)

# %% id="wWJxgEiDKEL_"
pd.options.display.max_rows
#pd.set_option('display.max_colwidth', -1)
pd.set_option('display.max_rows', 1000)
pd.set_option('display.max_columns', 1000)
pd.set_option('display.width', 1000)

# %% colab={"base_uri": "https://localhost:8080/", "height": 486} id="DGhWRuCQCQTA" outputId="241b63b1-ebb1-48e9-bd5d-3e314a851bb4"
df.head()

# %% colab={"base_uri": "https://localhost:8080/"} id="cQmohdbtELNW" outputId="1a66515a-a77c-45c6-ff20-8eaf37d1bd07"
df.info()


# %% [markdown] id="l66AHV6vNJeh"
# # Category Analysis

# %% id="vtBnWFMnOd-p" colab={"base_uri": "https://localhost:8080/"} outputId="da22fd0b-8eba-4b2d-8062-16de3f38957e"
#Helper function to reformat the given text
def reformat(text: str) -> str:
  text = text.replace('[', '')
  text = text.replace(']', '')
  text = text.replace('"', '')
  return text

#df.loc[:, 'product_category_tree'] = df['product_category_tree'].apply(lambda x: reformat(x))
df['product_category_tree'] = df['product_category_tree'].apply(lambda x: reformat(str(x)))

# %% colab={"base_uri": "https://localhost:8080/"} id="oJNmqPqvEge-" outputId="c01fd4ca-a2cc-40e5-8ccb-0435ecd98408"
# Finding the depth of the category trees
# Finding total number of categories in each level
cat_len = {}
for cat_tree in df.product_category_tree:
  number_of_categories = len(cat_tree.split(">>"))
  #print(number_of_categories)
  if number_of_categories not in cat_len:
    cat_len[number_of_categories] = 1
  else:
    cat_len[number_of_categories] += 1
print(cat_len)

# %% [markdown] id="g0Ht_7jNVZL8"
# **There are total 8 levels at max.**

# %% id="bCXMbMKvPAvT"
temp_df = df['product_category_tree'].str.split('>>', expand=True)
temp_df.columns = ['c0_name', 'c1_name', 'c2_name', 'c3_name', 'c4_name', 'c5_name', 'c6_name', 'c7_name']
for col in temp_df.columns:
  temp_df[col] = temp_df[col].apply(lambda x: x.strip() if x else x)

# %% [markdown] id="UJhF3GHaVgaY"
# **Considering only 4 levels from category tree**

# %% colab={"base_uri": "https://localhost:8080/", "height": 423} id="ud0bDggOPJvd" outputId="223398c1-4c37-4517-9b30-adc5306a7f57"
#Considering only 4 levels from category tree
temp_df =temp_df[['c0_name', 'c1_name', 'c2_name', 'c3_name']]
temp_df

# %% id="7jPLH2cRwW0e"
# concatenating df1 and df2 along rows
df_with_cat = pd.concat([df, temp_df], axis=1)
df_with_cat = df_with_cat.drop('product_category_tree', axis=1)

# %% id="vrVlzpJ_wrlf" colab={"base_uri": "https://localhost:8080/", "height": 486} outputId="259c980d-834e-4291-8259-4f236f520c09"
df_with_cat.head()

# %% id="k4zUOAnUO2_n"
#Saving the categories into an xlsx on local
columns = temp_df.columns
with pd.ExcelWriter('flipkart_cat_analysis_cat_depth4.xlsx') as writer:
  for col in columns:
    temp_df[col].value_counts().to_excel(writer, sheet_name=col)

# %% colab={"base_uri": "https://localhost:8080/"} id="0RBO9567YVZu" outputId="ccc0bd20-e399-43c6-87ba-970655b2aa7b"
df_with_cat.info()

# %% id="8zv8DEkELRzV"
#Checking for categories/sub-categories repetition
#non_null_image_df.reset_index(drop=True, inplace=True)
col1 = df_with_cat['c0_name']
col2 = df_with_cat['c1_name']
col3 = df_with_cat['c2_name']
col4 = df_with_cat['c3_name']

# %% colab={"base_uri": "https://localhost:8080/"} id="WSLm0YcbLYz0" outputId="93ccbbf6-a6d7-4a69-dffe-e925cd40145b"
'''
Categoty Tree [depth 4]:
root -> child -> sub-child -> leaf
'''

duplicate_index = []
for i in range(0,len(col1)):
    if (col1[i] == col2[i] and col1[i] and col2[i]):
      print('category repeating: root & child is same')
      print(i)
      print(col1[i],col2[i], col3[i], col4[i])
    if (col2[i] == col3[i] and col2[i] and col3[i]):
      print('category repeating: child & sub-child is same')
      print(i)
      print(col1[i],col2[i], col3[i], col4[i])
    if (col3[i] == col4[i] and col3[i] and col4[i]):
      print('category repeating:  sub-child & leaf is same')
      print(i)
      print(col1[i],"'",col2[i], ",", col3[i], ",", col4[i])
    if (col1[i] == col3[i] and col1[i] and col3[i]):
      print('category repeating: root & sub-child is same')
      print(i)
    if (col1[i] == col4[i] and col1[i] and col4[i]):
      print('category repeating: root & leaf is same')
      print(i)
    if (col2[i] == col4[i] and col2[i] and col4[i]):
      print('category repeating: child & leaf is same')
      print(i)

# %% [markdown] id="Crz-_TjgGmjJ"
# **Some of the sub-child & leaf are matching. We should remove the duplicate category**

# %% [markdown] id="x9aJU6AfdwRI"
# *Please check the index from above result and update below list accordingly, before running this cell*
#
# *This approach is to make leaf categories as Null*

# %% id="azj4L7HvPKzJ"
#please check the index and update below list, before running this cell
duplicate_index = [1681, 10086, 11241, 11252, 14921, 15062, 15063, 15091, 15468, 17591, 18809]
for i in duplicate_index:
  df_with_cat['c3_name'][i] = None

# %% [markdown] id="e3pO-6aeoe-c"
# # Extracting Product Attributes

# %% id="MFHW9gHmojuB"
#Extracting attributes from product specifications
import json
from typing import List, Dict

import jsonpickle
import pandas as pd
import re

import numpy as np
SPEC_MATCH_ONE = re.compile("(.*?)\\[(.*)\\](.*)")
SPEC_MATCH_TWO = re.compile("(.*?)=>\"(.*?)\"(.*?)=>\"(.*?)\"(.*)")

def parse_spec(specification: str):
    if pd.isna(specification):
      return None
    m = SPEC_MATCH_ONE.match(specification)
    out = {}
    position = 0
    if m is not None and m.group(2) is not None:
        phrase = ''
        for c in m.group(2):
            if c == '}':
                m2 = SPEC_MATCH_TWO.match(phrase)
                if m2 and m2.group(2) is not None and m2.group(4) is not None:
                    out[m2.group(2)]=m2.group(4)
                phrase = ''
            else:
                phrase += c
    json_string = jsonpickle.encode(out)
    print(json_string)
    return json_string


# %% colab={"base_uri": "https://localhost:8080/"} id="luMVFzqhdg4F" outputId="3bd9d3c4-51c0-47f2-d0db-a7c850a148ed"
# !pip3 show jsonpickle

# %% colab={"base_uri": "https://localhost:8080/"} id="G4jotD0_Wwm3" outputId="d8cd0b8b-0448-4732-9612-9089d51050e8"
df_with_cat['attributes'] = df_with_cat['product_specifications'].apply(parse_spec)

# %% [markdown] id="o2lDy7ZIiOjv"
# # Preparing Fine Tuning Dataset

# %% colab={"base_uri": "https://localhost:8080/"} id="dGJ23zUXdWws" outputId="e8bb668f-2ee2-4618-d7f7-0162979e3d2a"
df_with_cat.info()

# %% id="3Pz3cgngdu-y"
# Drop duplicate column product_specifications
df_with_cat.drop('product_specifications', axis=1, inplace=True)

# %% colab={"base_uri": "https://localhost:8080/"} id="fRJjh23bd4O_" outputId="e203058b-c593-4238-a588-5ca957d1d049"
df_with_cat.info()

# %% id="xa4S0iV-irUt"
#renaming column name
df_with_cat.rename(columns={'uniq_id':'Id','product_name':'Name', 'description':'Description', 'brand':'Brand','attributes':'Specifications'}, inplace=True)

# %% colab={"base_uri": "https://localhost:8080/", "height": 486} id="v7QvpyAseZPX" outputId="7eedeb0b-a9ec-48fd-9eb3-37971b3f11a4"
df_with_cat.head()

# %% colab={"base_uri": "https://localhost:8080/"} id="RzFGUxNNpgXh" outputId="0ec40528-f724-4223-caf1-ca726db3646a"
df_with_cat.c0_name.value_counts()

# %% id="j-ZUiyikqINO"
filtered_df = df_with_cat[df_with_cat['c0_name'] == 'Clothing']

# %% colab={"base_uri": "https://localhost:8080/"} id="15xl85XKqjCx" outputId="954c2a7a-6361-4eed-df0e-38badf973630"
filtered_df.c1_name.value_counts()

# %% id="9IlsOqGkrJvs"
values_to_filter = ["Women's Clothing", "Men's Clothing","Kids' Clothing"]
clothing_filtered_df = filtered_df[filtered_df['c1_name'].isin(values_to_filter)]

# %% colab={"base_uri": "https://localhost:8080/"} id="L94ewaiwruae" outputId="36b83c53-cc6e-41fb-a39e-75a8d4e42ef5"
clothing_filtered_df.c2_name.value_counts()

# %% colab={"base_uri": "https://localhost:8080/"} id="xH4QkiHhxta_" outputId="664e5f92-f2e7-4077-c666-75378717d322"
clothing_filtered_df.c3_name.value_counts()

# %% id="FHMyYyaGw9Fe"
import pandas as pd

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

# Filter to keep rows where 'c2_name' has count >=10
c2_filtered_df = filter_low_value_count_rows(clothing_filtered_df, 'c2_name', min_count=10)
#print(c2_filtered_df)


# %% colab={"base_uri": "https://localhost:8080/"} id="Bcs-15RErXrM" outputId="81d211de-1779-4fc6-9171-46b90a8e623f"
c2_filtered_df.c2_name.value_counts()

# %% id="W3SmNS9dyvkw"
c3_filtered_df = filter_low_value_count_rows(clothing_filtered_df, 'c3_name', min_count=10)

# %% colab={"base_uri": "https://localhost:8080/"} id="HkByEWyfyz-r" outputId="6f17214d-d921-4361-a578-594735fe5c4a"
c3_filtered_df.c3_name.value_counts()

# %% colab={"base_uri": "https://localhost:8080/"} id="JtQzer09zZQF" outputId="673c8cfd-6455-48d6-9044-75da47638de3"
c3_filtered_df.info()

# %% id="AirHYX6swqxv"
c3_filtered_df.to_csv('gs://'+BUCKET+'/flipkart_category_filtered_df.csv', index=False)

# %% id="WTaAlIoZPX7n"
context_df = c3_filtered_df[[
                'Name',
                'Description',
                'c1_name',
                'Specifications']]

# %% colab={"base_uri": "https://localhost:8080/", "height": 363} id="6ibXS5-ZznM-" outputId="97303822-4813-48e3-9091-85007f8eeff4"
context_df.head(10)

# %% id="ppIupP67OiIn"
# Convert the dataframe to JSONL format
context_df.to_json('context.jsonl', orient='records')

# %% id="ENyBiM0_oRYz"
# Data Format expected for fine tuning: {"context": " ", "question": " ", "answer": " "}
finetune_ds = pd.DataFrame(columns=['context', 'question', 'answer'])
finetune_ds['context'] = "Product Name: "+ context_df['Name']+ "<br> Product Category: "+ context_df['c1_name'] + "<br> Attributes: "+ context_df['Specifications'] +" <br> Description: "+ context_df['Description']


# %% colab={"base_uri": "https://localhost:8080/", "height": 363} id="jcyfOy6w0Snl" outputId="daf974da-e1f8-400c-ea7a-00d2ae2e7049"
finetune_ds.head(10)

# %% colab={"base_uri": "https://localhost:8080/"} id="bEP3dK-3UEQJ" outputId="64aa585f-4cec-4b83-ae33-1e9b62e89b15"
finetune_ds.info()

# %% id="jItUEOP-UavO"
# Drop the rows where the 'context' column is null
finetune_ds = finetune_ds.dropna(subset=['context'])
finetune_ds.reset_index(drop=True, inplace=True)

# %% id="XdsoK0kKWntQ"
# Drop the duplicates
finetune_ds = finetune_ds.drop_duplicates()
#finetune_ds.reset_index(drop=True, inplace=True)

# %% colab={"base_uri": "https://localhost:8080/", "height": 363} id="LprtCCxnVZ3M" outputId="001a322d-2070-4680-e998-8572316289bf"
finetune_ds.head(10)

# %% colab={"base_uri": "https://localhost:8080/"} id="7wto690VXJiL" outputId="8b098e25-d49b-4c0e-b52b-a4be5b5f5d6f"
finetune_ds.info()

# %% id="0QvoVkg-uh9w"
#Save the context into GCS
finetune_ds.context.to_csv('gs://'+BUCKET+'/fine_tuning_ds_context.csv', index=False)

# %% colab={"base_uri": "https://localhost:8080/"} id="KLpShGk43Spe" outputId="84951bfb-15f1-4f90-984c-7917cd586683"
from math import nan
import base64
import vertexai
from vertexai.generative_models import GenerativeModel, Part, FinishReason
import vertexai.preview.generative_models as generative_models
import re
import time
import numpy as np
import pandas as pd
generation_config = {
    "max_output_tokens": 200,
    "temperature": 0.7
}

safety_settings = {
    generative_models.HarmCategory.HARM_CATEGORY_HATE_SPEECH: generative_models.HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE,
    generative_models.HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT: generative_models.HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE,
    generative_models.HarmCategory.HARM_CATEGORY_SEXUALLY_EXPLICIT: generative_models.HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE,
    generative_models.HarmCategory.HARM_CATEGORY_HARASSMENT: generative_models.HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE,
}

num_questions = 3

def generate(context):
  vertexai.init(project=PROJECT_ID, location="us-central1")
  model = GenerativeModel(
    "gemini-1.5-flash-preview-0514",
  )

  prompt = f"Generate {num_questions} Search Queries in conversational tone and Answers for this product:\n{context}. Return the result without any formatting in a single line as Question : Answer"
  try:
    responses = model.generate_content(
        [prompt],
        generation_config=generation_config,
        safety_settings=safety_settings,
        stream=True,
    )
    qa=''
    for response in responses:
      qa+=response.text
    #print (qa)

    # Define the pattern to match questions and answers
    pattern = r"Question : (.*?) : Answer : (.*?)(?=\nQuestion :|$)"  # $ for end of string

    # Extract questions and answers
    matches = re.findall(pattern, qa, re.DOTALL)
    #print(matches)

    # Create a DataFrame
    temp_df = pd.DataFrame(matches, columns=["Question", "Answer"])
    temp_df['Context'] = context
    return temp_df
  except Exception as e:
    print(e)
    return None

result = pd.DataFrame()
for context in finetune_ds['context']:
  #print(context)
  if context!=np.nan:
    temp_df = generate(context)
    if not temp_df is None:
      result = pd.concat([result, temp_df], ignore_index=True)
    time.sleep(0.5) # Add a 1 second delay to avoid API rate limiting (adjust as needed)

# Now `result` contains all generated questions and answers
print(result)

# %% id="yjQlsmWkTEhh"
result.drop_duplicates(inplace=True)

# %% colab={"base_uri": "https://localhost:8080/", "height": 1000} id="OHS3TgCUTJDn" outputId="b3bf6803-d72f-45e1-8190-f185bf5b1c27"
result

# %% [markdown] id="i4mCisiuRz-h"
# ### Upload preprocessed data into GCS

# %% id="BpvPH3M1X7y0"
result.to_csv('gs://'+BUCKET+'/fine_tuning_ds.csv', index=False)

# %% id="6mhgPUzGrfv7"

# %% id="ZyvBT6hlrf0Z"