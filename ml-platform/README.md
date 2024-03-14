# Machine learning platform (MLP) on GKE reference architecture for enabling Machine Learning Operations (MLOps)

## Platform Principles

This reference architecture demonstrates how to build a GKE platform that facilitates Machine Learning. The reference architecture is based on the following principles:

- The platform admin will create the GKE platform using IaC tool like [Terraform][terraform]. The IaC will come with re-usable modules that can be referred to create more resources as the demand grows.
- The platform will be based on [GitOps][gitops].
- After the GKE platform has been created, cluster scoped resources on it will be created through [Config Sync][config-sync] by the admins.
- Platform admins will create a namespace per application and provide the application team member full access to it.
- The namespace scoped resources will be created by the Application/ML teams either via [Config Sync][config-sync] or through a deployment tool like [Cloud Deploy][cloud-deploy]

## CUJ and Personae addressed in the reference architecture

### Persona : Platform Admin

**CUJ 1** : Provide templates with built-in standard practices to stamp out GKE platforms to be used by ML Engineers, Data Scientists and Application teams.

**CUJ 2** : Provide GKE clusters.

**CUJ 2** : Provide space for the teams on GKE cluster to run their workloads and the permissions following the principle of least privilege.

**CUJ 3** : Provide secure methods to the ML Engineers, Data Scientist, Application teams and the Operators to connect to the private GKE clusters.

**CUJ 4** : Enforcing security policies on the underlying platform.

### Persona : ML Engineers

**CUJ 1** : Use ML tools like `ray` to perform their day to day tasks like data pre-processing, ML training etc.

**CUJ 2** : Use a development environment like Jupyter Notebook for faster inner loop of ML development. **[TBD]**

### Persona : Operators

**CUJ 1**: Act as a bridge between the Platform admins and the ML Engineers by providing and maintaining software needed by the ML engineers so they can focus on their job.

**CUJ 2**: Deploying the models. **[TBD]**

**CUJ 3**: Building observability on the models. **[TBD]**

**CUJ 4**: Operationalizing the models. **[TBD]**

## Prerequisites

- This guide is meant to be run on [Cloud Shell](https://shell.cloud.google.com) which comes preinstalled with the [Google Cloud SDK](https://cloud.google.com/sdk) and other tools that are required to complete this tutorial.
- Familiarity with following
  - [Google Kubernetes Engine][gke]
  - [Terraform][terraform]
  - [git][git]
  - [Google Configuration Management root-sync][root-sync]
  - [Google Configuration Management repo-sync][repo-sync]
  - [GitHub][github]

## Deploy a single environment reference architecture

This is the quick-start deployment guide. It can be used to set up an environment to familiarize yourself with the architecture and get an understanding of the concepts.

### Requirements

- New Google Cloud Project, preferably with no APIs enabled
- `roles/owner` IAM permissions on the project
- GitHub Personal Access Token, steps to create the token are provided below

### Configuration

- Create a [Personal Access Token][personal-access-token] in [GitHub][github]:

  Note: It is recommended to use a [machine user account][machine-user-account] for this but you can use a personal user account just to try this reference architecture.

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

- Set the project environment variables in Cloud Shell

  Replace the following values

  - `<PROJECT_ID>` is the ID of your existing Google Cloud project

  ```
  export MLP_PROJECT_ID="<PROJECT_ID>"
  export MLP_STATE_BUCKET="${MLP_PROJECT_ID}-tf-state"
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

- Create a Cloud Storage bucket to store the Terraform state

  ```
  gcloud storage buckets create gs://${MLP_STATE_BUCKET} --project ${MLP_PROJECT_ID}
  ```

### Run Terraform

- Clone the repository and change directory to the guide directory

  ```
  git clone https://github.com/GoogleCloudPlatform/ai-on-gke
  cd ai-on-gke/ml-platform
  ```

- Set environment variables

  ```
  export MLP_BASE_DIR=$(pwd) && \
  echo "export MLP_BASE_DIR=${MLP_BASE_DIR}" >> ${HOME}/.bashrc
  ```

- Set the configuration variables

  ```
  sed -i "s/YOUR_STATE_BUCKET/${MLP_STATE_BUCKET}/g" ${MLP_BASE_DIR}/terraform/backend.tf

  sed -i "s/YOUR_GITHUB_EMAIL/${MLP_GITHUB_EMAIL}/g" ${MLP_BASE_DIR}/terraform/mlp.auto.tfvars
  sed -i "s/YOUR_GITHUB_ORG/${MLP_GITHUB_ORG}/g" ${MLP_BASE_DIR}/terraform/mlp.auto.tfvars
  sed -i "s/YOUR_GITHUB_USER/${MLP_GITHUB_USER}/g" ${MLP_BASE_DIR}/terraform/mlp.auto.tfvars
  sed -i "s/YOUR_PROJECT_ID/${MLP_PROJECT_ID}/g" ${MLP_BASE_DIR}/terraform/mlp.auto.tfvars
  ```

- Create the resources

  ```
  cd ${MLP_BASE_DIR}/terraform && \
  terraform init && \
  terraform plan -input=false -var github_token="$(tr --delete '\n' < ${HOME}/secrets/mlp-github-token)" -out=tfplan && \
  terraform apply -input=false tfplan && \
  rm tfplan
  ```

### Review the resources

#### GKE clusters and ConfigSync

- Go to Google Cloud Console, click on the navigation menu and click on Kubernetes Engine > Clusters. You should see one cluster.

- Go to Google Cloud Console, click on the navigation menu and click on Kubernetes Engine > Config. If you haven't enabled GKE Enterprise in the project earlier, Click `LEARN AND ENABLE` button and then `ENABLE GKE ENTERPRISE`. You should see a RootSync and RepoSync object.
  ![configsync](docs/images/configsync.png)

#### Software installed via RepoSync and RootSync

Open Cloud Shell to execute the following commands:

- Store your GKE cluster name in env variable:

  `export GKE_CLUSTER=<GKE_CLUSTER_NAME>`

- Get cluster credentials:

  ```
  gcloud container fleet memberships get-credentials ${GKE_CLUSTER}
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
  cd ${MLP_BASE_DIR}/terraform && \
  terraform init && \
  terraform destroy -auto-approve -var github_token="$(tr --delete '\n' < ${HOME}/secrets/mlp-github-token)"
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
