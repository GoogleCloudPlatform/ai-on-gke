This directory contains the script for uploading a filtered and formatted file of prompts based on the "anon8231489123/ShareGPT_Vicuna_unfiltered" dataset to a given GCS path.

Example usage:
   python3 upload_sharegpt.py --gcs_path="gs://$BUCKET_NAME/ShareGPT_V3_unfiltered_cleaned_split_filtered_prompts.txt"

pre-work:
- upload_sharegpt.py assumes that the bucket already exists. If it does not exist, make sure that you create your bucket $BUCKET_NAME in your project prior to running the script. You can do that with the following command:
```
gcloud storage buckets create gs://$BUCKET_NAME --location=BUCKET_LOCATION
```

upload_sharegpt.py executes the following steps:
1. downloads local copy of the original dataset "anon8231489123/ShareGPT_Vicuna_unfiltered" via wget
2. filters out prompts from original dataset
3. uploads the filtered dataset to the given gcs bucket
4. deletes the local copy of "anon8231489123/ShareGPT_Vicuna_unfiltered" dataset

Assumes in your environment you:
- are running Python >= 3.9
- have access to use google storage APIs via Application Default Credentials (ADC)

You may need to do the following:
- run "pip install google-cloud-storage" to install storage client library dependencies
- run "gcloud auth application-default login" to enable ADC

For more information on running the google cloud storage API, see https://cloud.google.com/python/docs/reference/storage