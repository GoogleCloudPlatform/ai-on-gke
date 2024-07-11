# Testing

## Setup

- Clone the repository and change directory to the ml-platform directory

  ```
  git clone https://github.com/GoogleCloudPlatform/ai-on-gke && \
  cd ai-on-gke/best-practices/ml-platform
  ```

- Set environment variables

  ```
  export MLP_BASE_DIR=$(pwd) && \
  echo "export MLP_BASE_DIR=${MLP_BASE_DIR}" >> ${HOME}/.bashrc
  ```

- Configure GitHub credentials

  ```
  # Create a secure directory
  mkdir -p ${HOME}/secrets/
  chmod 700 ${HOME}/secrets

  # Create a secure file
  touch ${HOME}/secrets/mlp-github-token
  chmod 600 ${HOME}/secrets/mlp-github-token

  # Put your access token in the secure file using your preferred editor
  nano ${HOME}/secrets/mlp-github-token
  ```

- Configure GitLab credentials

  ```
  # Create a secure directory
  mkdir -p ${HOME}/secrets/
  chmod 700 ${HOME}/secrets

  # Create a secure file
  touch ${HOME}/secrets/mlp-gitlab-token
  chmod 600 ${HOME}/secrets/mlp-gitlab-token

  # Put your access token in the secure file using your preferred editor
  nano ${HOME}/secrets/mlp-gitlab-token
  ```

- Configure `kaggle` CLI credentials

  ```
  # Create a secure directory
  mkdir -p ${HOME}/.kaggle
  chmod 700 ${HOME}/.kaggle

  # Create a secure file
  touch ${HOME}/.kaggle/kaggle.json
  chmod 600 ${HOME}/.kaggle/kaggle.json

  # Put your API token in the secure file using your preferred editor
  nano ${HOME}/.kaggle/kaggle.json
  ```

## End to end tests

### Playground BYOP GitHub Dataprocessing

This test script will stand up the `playground` platform using GitHub for the Config Sync repository in an existing project, run the `dataprocessing` job, teardown the platform, and cleanup the environment.

- Set the GitHub organization or user namespace

  ```
  export MLP_GIT_NAMESPACE=
  ```

- Set GitHub user name

  ```
  export MLP_GIT_USER_NAME=
  ```

- Set GitHub email address

  ```
  export MLP_GIT_USER_EMAIL=
  ```

- Set Project ID

  ```
  export MLP_PROJECT_ID=
  ```

- Override IAP domain, if required. Defaults to the domain of the active `gcloud` user account(`gcloud auth list --filter=status:ACTIVE --format="value(account)" | awk -F@ '{print $2}'`)

  ```
  export MLP_IAP_DOMAIN=
  ```

- Ensure the OAuth consent screen for IAP is configured.

  ```
  gcloud iap oauth-brands list --project=${MLP_PROJECT_ID}
  ```

- Execute the script

  ```
  ${MLP_BASE_DIR}/test/scripts/e2e/playground_byop_gh_dataprocessing.sh
  ```

### Playground New Project GitHub Dataprocessing

This test script will initialize a new project, stand up the `playground` platform using GitHub for the Config Sync repository in , run the `dataprocessing` job, and delete the project.

- Set the GitHub organization or user namespace

  ```
  export MLP_GIT_NAMESPACE=
  ```

- Set GitHub user name

  ```
  export MLP_GIT_USER_NAME=
  ```

- Set GitHub email address

  ```
  export MLP_GIT_USER_EMAIL=
  ```

- Set the billing account ID to assign to the new project

  ```
  export MLP_BILLING_ACCOUNT_ID=
  ```

- Set the folder ID **OR** organization ID to use for the new project

  ```
  export MLP_FOLDER_ID=
  ```

  **-OR-**

  ```
  export MLP_ORG_ID=
  ```

- Override IAP domain, if required. Defaults to the domain of the active `gcloud` user account(`gcloud auth list --filter=status:ACTIVE --format="value(account)" | awk -F@ '{print $2}'`)

  ```
  export MLP_IAP_DOMAIN=
  ```

- Execute the script

  ```
  ${MLP_BASE_DIR}/test/scripts/e2e/playground_new_gh_dataprocessing.sh
  ```

## Unit tests

**WIP**
