# Distributed Data Processing Developer Guide

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
  cd best-practices/ml-platform/examples/use-case/data-processing/ray/src
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

- Set the Ray Cluster to run locally

  ```
  export RAY_CLUSTER_HOST=local
  ```

- Set the project for the GCS storage bucket

  ```
  gcloud config set project ${MLP_PROJECT_ID}
  ```

- Set the GCS storage bucket name

  ```
  export PROCESSING_BUCKET=
  ```

- Run the `preprocessing.py` script

  ```
  python ./preprocessing.py
  ```
