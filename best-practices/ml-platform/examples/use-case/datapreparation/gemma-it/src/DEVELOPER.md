# Fine Tuning PyTorch Developer Guide

- Install [`pyenv`](https://github.com/pyenv/pyenv?tab=readme-ov-file#installation)

- Install the `python` version

  ```
  pyenv install 3.12.4
  ```

- Clone the repository

  ```
  git clone https://github.com/GoogleCloudPlatform/ai-on-gke.git && \
  cd ai-on-gke
  ```

- Change directory to the `src` directory

  ```
  cd best-practices/ml-platform/examples/use-case/datapreparation/gemma-it/src
  ```

- Set the local `python` version

  ```
  pyenv local 3.12.4
  ```

- Create a virtual environment

  ```
  python -m venv venv
  ```

- Activate the virtual environment

  ```
  source venv/bin/activate
  ```

- Install the requirements

  ```
  pip install --no-cache-dir -r requirements.txt
  ```

- Set environment variables

  ```
  export PROJECT_ID=<project ID>
  export MLP_ENVIRONMENT_NAME=<environment name>

  export PROJECT_NUMBER=$(gcloud projects describe ${PROJECT_ID} --format="value(projectNumber)")

  export BUCKET="${PROJECT_ID}-${MLP_ENVIRONMENT_NAME}-flipkart-data"
  export NAMESPACE=ml-team
  export KSA=default
  export CLUSTER_NAME="mlp-${MLP_ENVIRONMENT_NAME}"
  export CLUSTER_REGION=us-central1
  export DOCKER_IMAGE_URL="us-docker.pkg.dev/${PROJECT_ID}/${MLP_ENVIRONMENT_NAME}-llm-finetuning/dataprep:v1.0.0"
  export REGION=us-central1

  export DATASET_INPUT_PATH="flipkart_preprocessed_dataset"
  export DATASET_INPUT_FILE="flipkart.csv"
  export DATASET_OUTPUT_PATH="dataset/output"
  export PROMPT_MODEL_ID="gemini-1.5-flash-001"

  ```

- Run the `dataprep.py` script

  ```
  python dataprep.py
  ```
