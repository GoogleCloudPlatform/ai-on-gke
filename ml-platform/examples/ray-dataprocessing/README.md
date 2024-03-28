# Distributed Data Processing with Ray on GKE

## Dataset
This is a pre-crawled public dataset, taken as a subset of a bigger dataset (more than 5.8 million products) that was created by extracting data from Flipkart, a leading Indian eCommerce store.

## Architecture
 ![DataPreprocessing](docs/images/DataPreprocessing.png)

## Data processing steps

The dataset has product information such as id, name, brand, description, image urls, product specifications. 

The preprocessing.py file does the following:
* Read the csv from Cloud Storage
* Clean up the product description text
* Extract image urls, validate and download the images into cloud storage
* Cleanup & extract attributes as key-value pairs

## How to use this repo:
1. Set environment variables

```
  PROJECT_ID=<your_project_id>
  PROCESSING_BUCKET=<your_bucket_name>
  DOCKER_IMAGE_URL=us-docker.pkg.dev/${PROJECT_ID}/dataprocessing/dp:v0.0.1
```
2. 
