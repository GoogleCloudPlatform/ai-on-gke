# Machine learning platform (MLP) on GKE reference architecture: Sandbox

This quick-start deployment guide can be used to set up an environment to familiarize yourself with the architecture and get an understanding of the concepts.

**NOTE: This environment is not intended to be a long lived environment. It is intended for temporary demonstration and learning purposes.**

### Requirements

In this guide you can choose to bring your project (BYOP) or have Terraform create a new project for you. The requirements are difference based on the option that you choose.

#### Option 1: Bring your own project (BYOP)

- Project ID of a new Google Cloud Project, preferably with no APIs enabled
- `roles/owner` IAM permissions on the project
- GitHub Personal Access Token, steps to create the token are provided below

#### Option 2: Terraform managed project

- Billing account ID
- Organization or folder ID
- `roles/billing.user` IAM permissions on the billing account specified
- `roles/resourcemanager.projectCreator` IAM permissions on the organization or folder specified
- GitHub Personal Access Token, steps to create the token are provided below

### Pull the source code

- Clone the repository and change directory to the guide directory

  ```
  git clone https://github.com/GoogleCloudPlatform/ai-on-gke && \
  cd ai-on-gke/best-practices/ml-platform
  ```

- Set environment variables

  ```
  export MLP_BASE_DIR=$(pwd) && \
  echo "export MLP_BASE_DIR=${MLP_BASE_DIR}" >> ${HOME}/.bashrc

  cd examples/platform/sandbox && \
  export MLP_TYPE_BASE_DIR=$(pwd) && \
  echo "export MLP_TYPE_BASE_DIR=${MLP_TYPE_BASE_DIR}" >> ${HOME}/.bashrc
  ```

### GitHub Configuration

- Create a [Personal Access Token][personal-access-token] in [GitHub][github]:

  Note: It is recommended to use a [machine user account][machine-user-account] for this but you can use a personal user account just to try this reference architecture.

  **Fine-grained personal access token**

  - Go to https://github.com/settings/tokens and login using your credentials
  - Click "Generate new token" >> "Generate new token (Beta)".
  - Enter a Token name.
  - Select the expiration.
  - Select the Resource owner.
  - Select All repositories
  - Set the following Permissions:
    - Repository permissions
      - Administration: Read and write
      - Content: Read and write
  - Click "Generate token"

  **Personal access tokens (classic)**

  - Go to https://github.com/settings/tokens and login using your credentials
  - Click "Generate new token" >> "Generate new token (classic)".
  - You will be directed to a screen to created the new token. Provide the note and expiration.
  - Choose the following two access:
    - [x] repo - Full control of private repositories
    - [x] delete_repo - Delete repositories
  - Click "Generate token"

- Store the token in a secure file.

  ```
  # Create a secure directory
  mkdir -p ${HOME}/secrets/
  chmod go-rwx ${HOME}/secrets

  # Create a secure file
  touch ${HOME}/secrets/mlp-github-token
  chmod go-rwx ${HOME}/secrets/mlp-github-token

  # Put the token in the secure file using your preferred editor
  nano ${HOME}/secrets/mlp-github-token
  ```

- Set the GitHub environment variables in Cloud Shell

  Replace the following values:

  - `<GITHUB_ORGANIZATION>` is the GitHub organization or user namespace to use for the repositories
  - `<GITHUB_USER>` is the GitHub account to use for authentication
  - `<GITHUB_EMAIL>` is the email address to use for commit

  ```
  export MLP_GITHUB_ORG="<GITHUB_ORGANIZATION>"
  export MLP_GITHUB_USER="<GITHUB_USER>"
  export MLP_GITHUB_EMAIL="<GITHUB_EMAIL>"
  ```

- Set the configuration variables

  ```
  sed -i "s/YOUR_GITHUB_EMAIL/${MLP_GITHUB_EMAIL}/g" ${MLP_TYPE_BASE_DIR}/mlp.auto.tfvars
  sed -i "s/YOUR_GITHUB_ORG/${MLP_GITHUB_ORG}/g" ${MLP_TYPE_BASE_DIR}/mlp.auto.tfvars
  sed -i "s/YOUR_GITHUB_USER/${MLP_GITHUB_USER}/g" ${MLP_TYPE_BASE_DIR}/mlp.auto.tfvars
  ```

### Project Configuration

You only need to complete the section for the option that you have selected (either option 1 or 2).

#### Option 1: Bring your own project (BYOP)

- Set the project environment variables in Cloud Shell

  Replace the following values

  - `<PROJECT_ID>` is the ID of your existing Google Cloud project

  ```
  export MLP_PROJECT_ID="<PROJECT_ID>"
  export MLP_STATE_BUCKET="${MLP_PROJECT_ID}-tf-state"
  ```

- Set the default `gcloud` project

  ```
  gcloud config set project ${MLP_PROJECT_ID}
  ```

- Authorize `gcloud`

  ```
  gcloud auth login --activate --no-launch-browser --quiet --update-adc
  ```

- Create a Cloud Storage bucket to store the Terraform state

  ```
  gcloud storage buckets create gs://${MLP_STATE_BUCKET} --project ${MLP_PROJECT_ID}
  ```

- Set the configuration variables

  ```
  sed -i "s/YOUR_STATE_BUCKET/${MLP_STATE_BUCKET}/g" ${MLP_TYPE_BASE_DIR}/backend.tf
  sed -i "s/YOUR_PROJECT_ID/${MLP_PROJECT_ID}/g" ${MLP_TYPE_BASE_DIR}/mlp.auto.tfvars
  ```

You can now deploy the platform with Terraform in the [next section](#run-terraform).

#### Option 2: Terraform managed project

- Set the configuration variables

  ```
  nano ${MLP_BASE_DIR}/terraform/features/initialize/initialize.auto.tfvars
  ```

  ```
  project = {
    billing_account_id = "XXXXXX-XXXXXX-XXXXXX"
    folder_id          = "############"
    name               = "mlp"
    org_id             = "############"
  }
  ```

  > `project.billing_account_id` the billing account ID
  >
  > Enter either `project.folder_id` **OR** `project.org_id`  
  > `project.folder_id` the folder ID  
  > `project.org_id` the organization ID

- Authorize `gcloud`

  ```
  gcloud auth login --activate --no-launch-browser --quiet --update-adc
  ```

- Create a new project

  ```
  cd ${MLP_BASE_DIR}/terraform/features/initialize
  terraform init && \
  terraform plan -input=false -out=tfplan && \
  terraform apply -input=false tfplan && \
  rm tfplan && \
  terraform init -force-copy -migrate-state && \
  rm -rf state
  ```

You can now deploy the platform with Terraform in the [next section](#run-terraform).

### Run Terraform

Before running Terraform, make sure that the Service Usage API is enable.

- Enable Service Usage API

  `gcloud services enable serviceusage.googleapis.com`

- Create the resources

  ```
  cd ${MLP_TYPE_BASE_DIR} && \
  terraform init && \
  terraform plan -input=false -var github_token="$(tr --delete '\n' < ${HOME}/secrets/mlp-github-token)" -out=tfplan && \
  terraform apply -input=false tfplan
  rm tfplan
  ```

### Review the resources

#### GKE clusters and ConfigSync

- Go to Google Cloud Console, click on the navigation menu and click on Kubernetes Engine > Clusters. You should see one cluster.

- Go to Google Cloud Console, click on the navigation menu and click on Kubernetes Engine > Config. If you haven't enabled GKE Enterprise in the project earlier, Click `LEARN AND ENABLE` button and then `ENABLE GKE ENTERPRISE`. You should see a RootSync and RepoSync object.
  ![configsync](/best-practices/ml-platform/docs/images/configsync.png)

#### Software installed via RepoSync and RootSync

Open Cloud Shell to execute the following commands:

- Store your GKE cluster name in env variable:

  `export GKE_CLUSTER=<GKE_CLUSTER_NAME>`

- Get cluster credentials:

  ```
  gcloud container fleet memberships get-credentials ${GKE_CLUSTER}
  ```

  The output will be similar to the following:

  ```
  Starting to build Gateway kubeconfig...
  Current project_id: mlops-platform-417609
  A new kubeconfig entry "connectgateway_mlops-platform-417609_global_gke-ml-dev" has been generated and set as the current context.
  ```

- Fetch KubeRay operator CRDs

  ```
  kubectl get crd | grep ray
  ```

  The output will be similar to the following:

  ```
  rayclusters.ray.io   2024-02-12T21:19:06Z
  rayjobs.ray.io       2024-02-12T21:19:09Z
  rayservices.ray.io   2024-02-12T21:19:12Z
  ```

- Fetch KubeRay operator pod

  ```
  kubectl get pods
  ```

  The output will be similar to the following:

  ```
  NAME                                READY   STATUS    RESTARTS   AGE
  kuberay-operator-56b8d98766-2nvht   1/1     Running   0          6m26s
  ```

- Check the namespace `ml-team` created:

  ```
  kubectl get ns | grep ml-team
  ```

  The output will be similar to the following:

  ```
  ml-team                        Active   21m
  ```

- Check the RepoSync object created `ml-team` namespace:
  ```
  kubectl get reposync -n ml-team
  ```

- Check the `raycluster` in `ml-team` namespace

  ```
  kubectl get raycluster -n ml-team
  ```

  The output will be similar to the following:

  ```
  NAME                  DESIRED WORKERS   AVAILABLE WORKERS   STATUS   AGE
  ray-cluster-kuberay   1                 1                   ready    29m
  ```

- Check the head and worker pods of kuberay in `ml-team` namespace

  ```
  kubectl get pods -n ml-team
  ```

  The output will be similar to the following:
  ```
  NAME                                           READY   STATUS    RESTARTS   AGE
  ray-cluster-kuberay-head-sp6dg                 2/2     Running   0          3m21s
  ray-cluster-kuberay-worker-workergroup-rzpjw   2/2     Running   0          3m21s
  ```

### Cleanup

- Destroy the resources

  ```
  cd ${MLP_TYPE_BASE_DIR} && \
  terraform init && \
  terraform destroy -auto-approve -var github_token="$(tr --delete '\n' < ${HOME}/secrets/mlp-github-token)" && \
  rm -rf .terraform .terraform.lock.hcl
  ```

#### Project

You only need to complete the section for the option that you have selected.

##### Option 1: Bring your own project (BYOP)

- Delete the project

  ```
  gcloud projects delete ${MLP_PROJECT_ID}
  ```

#### Option 2: Terraform managed project

- Destroy the project

  ```
  cd ${MLP_BASE_DIR}/terraform/features/initialize && \
  TERRAFORM_BUCKET_NAME=$(grep bucket backend.tf | awk -F"=" '{print $2}' | xargs) && \
  cp backend.tf.local backend.tf && \
  terraform init -force-copy -lock=false -migrate-state && \
  gsutil -m rm -rf gs://${TERRAFORM_BUCKET_NAME}/* && \
  terraform init && \
  terraform destroy -auto-approve  && \
  rm -rf .terraform .terraform.lock.hcl
  ```

[gitops]: https://about.gitlab.com/topics/gitops/
[repo-sync]: https://cloud.google.com/anthos-config-management/docs/reference/rootsync-reposync-fields
[root-sync]: https://cloud.google.com/anthos-config-management/docs/reference/rootsync-reposync-fields
[config-sync]: https://cloud.google.com/anthos-config-management/docs/config-sync-overview
[cloud-deploy]: https://cloud.google.com/deploy?hl=en
[terraform]: https://www.terraform.io/
[gke]: https://cloud.google.com/kubernetes-engine?hl=en
[git]: https://git-scm.com/
[github]: https://github.com/
[gcp-project]: https://cloud.google.com/resource-manager/docs/creating-managing-projects
[personal-access-token]: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens
[machine-user-account]: https://docs.github.com/en/get-started/learning-about-github/types-of-github-accounts
