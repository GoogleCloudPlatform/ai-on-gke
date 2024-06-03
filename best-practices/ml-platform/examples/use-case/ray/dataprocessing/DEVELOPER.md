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
  cd best-practices/ml-platform/examples/use-case/ray/dataprocessing/src
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

- Set the required environment variables

  ```
  export PROCESSING_BUCKET=<bucket-name>
  export RAY_CLUSTER_HOST=local
  ```

- Run the `preprocessing.py` script

  ```
  python ./preprocessing.py
  ```