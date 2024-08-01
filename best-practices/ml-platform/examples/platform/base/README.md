# Base Machine learning platform (MLP) on GKE reference architecture

This deployment guide can be used to set up a machine learning platform on GKE

## Architecture

For more information about the architecture, see the [Playground Machine learning platform (MLP) on GKE: Architecture](/best-practices/ml-platform/docs/platform/base/architecture.md) document.

For an outline of products and features used in the platform, see the [Platform Products and Features](/best-practices/ml-platform/docs/platform/products-and-features.md) document.

## Requirements

### Project

#### Recommended Projects

- `operations` project

- `platform-eng` project

- `infra` project

#### Permissions

### Quota

#### GPU

TODO: Add GPU quota recommendations

#### TPU

TODO: Add GPU quota recommendations

## Pull the source code

**NOTE: This tutorial is designed to be run from Cloud Shell in the Google Cloud Console.**

- Clone the repository and change directory to the guide directory

  ```
  git clone https://github.com/GoogleCloudPlatform/ai-on-gke && \
  cd ai-on-gke/best-practices/ml-platform
  ```

- Set environment variables

  ```
  export MLP_BASE_DIR=$(pwd) && \
  echo "export MLP_BASE_DIR=${MLP_BASE_DIR}" >> ${HOME}/.bashrc
  ```

  ```
  cd examples/platform/base && \
  export MLP_TYPE_BASE_DIR=$(pwd) && \
  echo "export MLP_TYPE_BASE_DIR=${MLP_TYPE_BASE_DIR}" >> ${HOME}/.bashrc
  ```

## Git configuration

- Set environment variables

  ```
  export MLP_PLAT_ENG_GIT_TOKEN_FILE=
  export MLP_PLAT_ENG_GIT_NAMESPACE=
  export MLP_PLAT_ENG_GIT_USER_EMAIL=
  export MLP_PLAT_ENG_GIT_USER_NAME=
  ```

- Set the configuration variables

  ```
  sed -i "s/^\(^platform_eng_git_namespace[[:blank:]]*=\).*$/\1 \"${MLP_PLAT_ENG_GIT_NAMESPACE}\"/" ${MLP_TYPE_BASE_DIR}/shared_config/platform_eng.auto.tfvars
  sed -i "s/^\(^platform_eng_git_user_email[[:blank:]]*=\).*$/\1 \"${MLP_PLAT_ENG_GIT_USER_EMAIL}\"/" ${MLP_TYPE_BASE_DIR}/shared_config/platform_eng.auto.tfvars
  sed -i "s/^\(^platform_eng_git_user_name[[:blank:]]*=\).*$/\1 \"${MLP_PLAT_ENG_GIT_USER_NAME}\"/" ${MLP_TYPE_BASE_DIR}/shared_config/platform_eng.auto.tfvars
  ```

## Platform engineering project configuration

- Set the platform engineering project environment variables

  Replace the following values

  - `<PROJECT_ID>` is the ID of your existing Google Cloud project

  ```
  export MLP_PLAT_ENG_PROJECT_ID="<PROJECT_ID>"
  ```

  ```
  export MLP_PLAT_ENG_TERRAFORM_BUCKET="${MLP_PLAT_ENG_PROJECT_ID}-terraform"
  ```

- Authorize `gcloud`

  ```
  gcloud auth login --activate --no-launch-browser --quiet --update-adc
  ```

- Create a Cloud Storage bucket to store the Terraform state

  ```
  gcloud storage buckets create gs://${MLP_PLAT_ENG_TERRAFORM_BUCKET} --project ${MLP_PLAT_ENG_PROJECT_ID} --uniform-bucket-level-access
  ```

- Set the configuration variables

  ```
  sed -i "s/^\(^platform_eng_project_id[[:blank:]]*=\).*$/\1 \"${MLP_PLAT_ENG_PROJECT_ID}\"/" ${MLP_TYPE_BASE_DIR}/shared_config/platform_eng.auto.tfvars
  sed -i "s/^\([[:blank:]]*bucket[[:blank:]]*=\).*$/\1 \"${MLP_PLAT_ENG_TERRAFORM_BUCKET}\"/" ${MLP_TYPE_BASE_DIR}/platform_eng/backend.tf
  ```

## Create the platform engineering resources

Before running Terraform, make sure that the Service Usage API is enable.

- Enable Service Usage API

  ```
  gcloud services enable serviceusage.googleapis.com --project ${MLP_PLAT_ENG_PROJECT_ID}
  ```

- Create the resources

  ```
  cd ${MLP_TYPE_BASE_DIR}/platform_eng && \
  terraform init && \
  terraform plan -input=false -var platform_eng_git_token="$(tr --delete '\n' < ${MLP_PLAT_ENG_GIT_TOKEN_FILE})" -out=tfplan && \
  terraform apply -input=false tfplan && \
  rm tfplan
  ```

## Cleanup

### Resources

- Destroy the resources

  ```
  cd ${MLP_TYPE_BASE_DIR} && \
  terraform init && \
  terraform destroy -auto-approve -var github_token="$(tr --delete '\n' < ${HOME}/secrets/mlp-github-token)" && \
  rm -rf .terraform .terraform.lock.hcl
  ```

  See [Cleanup resources errors](#cleanup-resources-errors) in the Troubleshooting section if the destroy does not complete successfully.

### Project

You only need to complete the section for the option that you have selected.

#### Option 1: Bring your own project (BYOP)

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

### Code Repository

- Restore modified files

  ```
  cd ${MLP_BASE_DIR} && \
  git restore \
  examples/platform/base/backend.tf \
  examples/platform/base/mlp.auto.tfvars \
  terraform/features/initialize/backend.tf \
  terraform/features/initialize/backend.tf.bucket \
  terraform/features/initialize/initialize.auto.tfvars
  ```

- Remove Terraform files and temporary files

  ```
  cd ${MLP_BASE_DIR} && \
  rm -rf \
  examples/platform/base/.terraform \
  examples/platform/base/.terraform.lock.hcl \
  terraform/features/initialize/.terraform \
  terraform/features/initialize/.terraform.lock.hcl \
  terraform/features/initialize/backend.tf.local \
  terraform/features/initialize/state
  ```

## Troubleshooting

### Create resources errors

---

```
│ Error: Error creating Client: googleapi: Error 404: Requested entity was not found.
│
│   with google_iap_client.ray_head_client,
│   on gateway.tf line ###, in resource "google_iap_client" "ray_head_client":
│  ###: resource "google_iap_client" "ray_head_client" {
│
```

The OAuth Consent screen was not configured, see the [Configure OAuth consent screen for IAP](#configure-oauth-consent-screen-for-iap) section.

---

```
│ Error: googleapi: Error 400: Service ray-dashboard.ml-team.mlp.endpoints.<project_id>.cloud.goog has been deleted and
will be purged after 30 days. To reuse this service, please undelete the service following https://cloud.google.com/service-infrastructure/docs/create-services#undeleting., failedPrecondition
│
│   with google_endpoints_service.ray_dashboard_https,
│   on gateway.tf line ##, in resource "google_endpoints_service" "ray_dashboard_https":
│   ##: resource "google_endpoints_service" "ray_dashboard_https" {
│
```

The endpoint is in a deleted state and needs to be undeleted, run the following command and then rerun the Terraform apply.

```
MLP_PROJECT_ID=$(grep environment_project_id ${MLP_TYPE_BASE_DIR}/mlp.auto.tfvars | awk -F"=" '{print $2}' | xargs)
gcloud endpoints services undelete ray-dashboard.ml-team.mlp.endpoints.${MLP_PROJECT_ID}.cloud.goog --quiet
```

---

### Cleanup resources errors

---

```
│ Error: Error waiting for Deleting Network: The network resource 'projects/<project_id>/global/networks/ml-vpc-dev'
is already being used by 'projects/<project_id>/zones/us-central1-a/networkEndpointGroups/k8s1-XXXXXXXX-ml-team-ray-cluster-kuberay-head-svc-XXX-XXXXXXXX'
│
│
│
```

There were orphaned [network endpoint groups (NEGs)](https://console.cloud.google.com/compute/networkendpointgroups/list) in the project. Delete the network endpoint groups and retry the Terraform destroy.

```
gcloud compute network-endpoint-groups list --project ${MLP_PROJECT_ID}
```

---

```
│ Error: Error waiting for Deleting Network: The network resource 'projects/<project_id>/global/networks/ml-vpc-dev'
is already being used by 'projects/<project-id>/global/firewalls/gkegw1-XXXX-l7-ml-vpc-dev-global'
│
│
│
```

There were orphaned [VPC firewall rules](https://console.cloud.google.com/net-security/firewall-manager/firewall-policies/list) in the project. Delete the VPC firewall rules and retry the Terraform destroy.

```
gcloud compute firewall-rules list --project ${MLP_PROJECT_ID}
```

---

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
