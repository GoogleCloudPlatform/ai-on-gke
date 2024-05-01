import os
import ray
import pandas as pd
from typing import List
import urllib.request, urllib.error
import time
from google.cloud import storage
import spacy
import jsonpickle
import re

IMAGE_BUCKET = os.environ['PROCESSING_BUCKET']
RAY_CLUSTER_HOST = os.environ['RAY_CLUSTER_HOST']
GCS_IMAGE_FOLDER = 'flipkart_images'

@ray.remote(resources={"n2_cpu": 1})
def get_clean_df(df):

    def extract_url(image_list: str) -> List[str]:
        image_list = image_list.replace('[', '')
        image_list = image_list.replace(']', '')
        image_list = image_list.replace('"', '')
        image_urls = image_list.split(',')
        return image_urls

    def download_image(image_url, image_file_name, destination_blob_name):
        storage_client = storage.Client()
        image_found_flag = False
        try:
            urllib.request.urlretrieve(image_url, image_file_name)
            bucket = storage_client.bucket(IMAGE_BUCKET)
            blob = bucket.blob(destination_blob_name)
            blob.upload_from_filename(image_file_name)
            print(
                f"File {image_file_name} uploaded to {destination_blob_name}."
            )
            image_found_flag = True
        except urllib.error.HTTPError:
            print("HTTPError exception")
        except urllib.error.URLError:
            print("URLError exception")
        except:
            print("Unknown exception")
        return image_found_flag

    def prep_product_desc(df):
        # Cleaning the description text
        spacy.cli.download("en_core_web_sm")
        model = spacy.load("en_core_web_sm")

        def parse_nlp_description(description) -> str:
            if not pd.isna(description):
                doc = model(description.lower())
                lemmas = []
                for token in doc:
                    if token.lemma_ not in lemmas and not token.is_stop and token.is_alpha:
                        lemmas.append(token.lemma_)
                return ' '.join(lemmas)

        df['description'] = df['description'].apply(parse_nlp_description)
        return df

    # Extract product attributes as key-value pair
    def parse_attributes(specification: str):
        spec_match_one = re.compile("(.*?)\\[(.*)\\](.*)")
        spec_match_two = re.compile("(.*?)=>\"(.*?)\"(.*?)=>\"(.*?)\"(.*)")
        if pd.isna(specification):
            return None
        m = spec_match_one.match(specification)
        out = {}
        if m is not None and m.group(2) is not None:
            phrase = ''
            for c in m.group(2):
                if c == '}':
                    m2 = spec_match_two.match(phrase)
                    if m2 and m2.group(2) is not None and m2.group(4) is not None:
                        out[m2.group(2)] = m2.group(4)
                    phrase = ''
                else:
                    phrase += c
        json_string = jsonpickle.encode(out)
        return json_string

    def get_product_image(df):
        products_with_no_image_count = 0
        products_with_no_image = []
        gcs_image_url = []
        image_found_flag = False
        for id, image_list in zip(df['uniq_id'], df['image']):

            if pd.isnull(image_list):  # No image url
                # print("WARNING: No image url: product ", id)
                products_with_no_image_count += 1
                products_with_no_image.append(id)
                gcs_image_url.append(None)
                continue
            image_urls = extract_url(image_list)
            for index in range(len(image_urls)):
                image_url = image_urls[index]
                image_file_name = '{}_{}.jpg'.format(id, index)
                destination_blob_name = GCS_IMAGE_FOLDER + '/' + image_file_name
                image_found_flag = download_image(image_url, image_file_name, destination_blob_name)
                if image_found_flag:
                    gcs_image_url.append('gs://' + IMAGE_BUCKET + '/' + destination_blob_name)
                    break
            if not image_found_flag:
                # print("WARNING: No image: product ", id)
                products_with_no_image_count += 1
                products_with_no_image.append(id)
                gcs_image_url.append(None)

        # appending gcs image uri into dataframe
        gcs_image_loc = pd.DataFrame(gcs_image_url, index=df.index)
        gcs_image_loc.columns = ["image_uri"]
        df_with_gcs_image_uri = pd.concat([df, gcs_image_loc], axis=1)
        return df_with_gcs_image_uri

    df_with_gcs_image_uri = get_product_image(df)
    df_with_desc = prep_product_desc(df_with_gcs_image_uri)
    df_with_desc['attributes'] = df_with_desc['product_specifications'].apply(parse_attributes)

    return df_with_desc


def split_dataframe(df, chunk_size=199):
    chunks = list()
    num_chunks = len(df) // chunk_size + 1
    for i in range(num_chunks):
        chunks.append(df[i * chunk_size:(i + 1) * chunk_size])
    return chunks


# This function invokes ray task
def run_remote():
    df = pd.read_csv('gs://'+IMAGE_BUCKET+'/flipkart_raw_dataset/flipkart_com-ecommerce_sample.csv')
    df = df[['uniq_id','product_name','description','brand','image','product_specifications']]
    runtime_env = {"pip": ["google-cloud-storage==2.16.0", "spacy==3.7.4", "jsonpickle==3.0.3"]}
    ray.init("ray://"+RAY_CLUSTER_HOST, runtime_env=runtime_env)
    print("STARTED")
    start_time = time.time()
    res = split_dataframe(df)
    results = ray.get([get_clean_df.remote(res[i]) for i in range(len(res))])
    print("FINISHED IN ")
    duration = time.time() - start_time
    print(duration)
    ray.shutdown()
    result_df = pd.concat(results, axis=0, ignore_index=True)
    result_df.to_csv('gs://'+IMAGE_BUCKET+'/flipkart_preprocessed_dataset/flipkart.csv', index=False)
    return result_df


def main():
    clean_df = run_remote()


if __name__ == "__main__":
    """ This is executed when run from the command line """
    main()
