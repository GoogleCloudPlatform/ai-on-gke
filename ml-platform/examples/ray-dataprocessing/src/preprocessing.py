import os
import ray
import pandas as pd
from typing import List
import urllib.request, urllib.error
import time
from google.cloud import storage

IMAGE_BUCKET = os.environ['PROCESSING_BUCKET']
RAY_CLUSTER_HOST = os.environ['RAY_CLUSTER_HOST']
GCS_IMAGE_FOLDER = 'flipkart_images'

#@ray.remote(num_cpus=0.2)
@ray.remote(num_cpus=1)
def get_product_image(df):

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
        except urllib.error.URLError:
            print("URLError exception")
        except urllib.error.HTTPError:
            print("HTTPError exception")
        except urllib.error.HTTPException:
            print("HTTPException exception")
        except:
            print("Unknown exception")
        return image_found_flag
    
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
    # gcs_image_loc = gcs_image_loc.reindex(df.index)
    df_with_gcs_image_uri = pd.concat([df, gcs_image_loc], axis=1)
    # df_with_gcs_image_uri = df_with_gcs_image_uri.drop('image', axis=1)

    return df_with_gcs_image_uri


def split_dataframe(df, chunk_size=199):
    chunks = list()
    num_chunks = len(df) // chunk_size + 1
    for i in range(num_chunks):
        chunks.append(df[i * chunk_size:(i + 1) * chunk_size])
    return chunks


# This function invokes ray task
def run_remote():
    df = pd.read_csv('gs://'+IMAGE_BUCKET+'/flipkart_raw_dataset/flipkart_com-ecommerce_sample.csv')
    runtime_env = {"pip": ["google-cloud-storage==2.16.0"]}
    ray.init("ray://"+RAY_CLUSTER_HOST, runtime_env=runtime_env)
    print("STARTED")
    start_time = time.time()
    res = split_dataframe(df)
    results = ray.get([get_product_image.remote(res[i]) for i in range(len(res))])
    print("FINISHED IN ")
    duration = time.time() - start_time
    print(duration)
    ray.shutdown()
    return (results)


def main():
    run_remote()

if __name__ == "__main__":
    """ This is executed when run from the command line """
    main()