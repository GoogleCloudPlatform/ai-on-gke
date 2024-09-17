# Fine Tuning PyTorch Developer Guide

- Install [`pyenv`](https://github.com/pyenv/pyenv?tab=readme-ov-file#installation)

- Install the `python` version

  ```
  pyenv install 3.10.14
  ```

- Clone the repository

  ```
  git clone https://github.com/GoogleCloudPlatform/ai-on-gke.git && \
  cd ai-on-gke
  ```

- Change directory to the `src` directory

  ```
  cd best-practices/ml-platform/examples/use-case/fine-tuning/pytorch/src
  ```

- Set the local `python` version

  ```
  pyenv local 3.10.14
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
  export MLP_ENVIRONMENT_NAME=<environment-name>
  export MLP_PROJECT_ID=<project-id>
  export HF_TOKEN_FILE=${HOME}/secrets/mlp-hugging-face-token

  export PROJECT_ID=${MLP_PROJECT_ID}
  gcloud config set project ${PROJECT_ID}
  export PROJECT_NUMBER=$(gcloud projects describe ${PROJECT_ID} --format="value(projectNumber)")

  export TRAINING_DATASET_BUCKET="${PROJECT_ID}-${MLP_ENVIRONMENT_NAME}-processing"
  export MODEL_BUCKET="${PROJECT_ID}-${MLP_ENVIRONMENT_NAME}-model"
  export CLUSTER_NAME="mlp-${MLP_ENVIRONMENT_NAME}"
  export NAMESPACE=ml-team
  export KSA=default
  export HF_TOKEN=$(tr --delete '\n' <${HF_TOKEN_FILE})
  export DOCKER_IMAGE_URL="us-docker.pkg.dev/${PROJECT_ID}/${MLP_ENVIRONMENT_NAME}-llm-finetuning/finetune:v1.0.0"

  export EXPERIMENT=""
  export MLFLOW_ENABLE="false"
  export MLFLOW_ENABLE_SYSTEM_METRICS_LOGGING="false"
  export MLFLOW_TRACKING_URI=""
  export TRAINING_DATASET_PATH="dataset/output/training"
  export MODEL_PATH="/model-data/model-gemma2/experiment"
  export MODEL_NAME="google/gemma-2-9b-it"
  export ACCELERATOR="l4"
  ```

- Install `gcsfuse`

  ```
  export GCSFUSE_REPO=gcsfuse-`lsb_release -c -s` && \
  echo "deb [signed-by=/usr/share/keyrings/cloud.google.asc] https://packages.cloud.google.com/apt $GCSFUSE_REPO main" | sudo tee /etc/apt/sources.list.d/gcsfuse.list && \
  curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo tee /usr/share/keyrings/cloud.google.asc && \
  sudo apt-get update && \
  sudo apt-get install -y gcsfuse
  ```

- Create the model bucket mount directory

  ```
  export MOUNT_DIR="/model-data"
  sudo mkdir -p ${MOUNT_DIR}
  sudo chown ${USER} ${MOUNT_DIR}
  ```

- Mount your model bucket using `gcsfuse`

  ```
  gcsfuse ${MODEL_BUCKET} ${MOUNT_DIR}
  ```

- Run the `fine_tune.py` script

  ```
  accelerate launch \
  --config_file fsdp_config.yaml \
  --debug \
  fine_tune.py
  ```

- Unmount the model bucket

  ```
  fusermount -u ${MOUNT_DIR}
  ```
