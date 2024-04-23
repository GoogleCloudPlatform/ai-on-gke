# Machine learning platform (MLP) on GKE reference architecture: Sandbox

This quick-start deployment guide can be used to set up an environment to familiarize yourself with the architecture and get an understanding of the concepts.

**NOTE: This environment is not intended to be a long lived environment. It is intended for temporary demonstration and learning purposes.**

## Requirements

### Project

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

### Quota

The default quota given to a project should be sufficient for this guide.

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
  cd examples/platform/sandbox && \
  export MLP_TYPE_BASE_DIR=$(pwd) && \
  echo "export MLP_TYPE_BASE_DIR=${MLP_TYPE_BASE_DIR}" >> ${HOME}/.bashrc
  ```

## GitHub Configuration

- Create a [Personal Access Token][personal-access-token] in [GitHub][github]:

  Note: It is recommended to use a [machine user account][machine-user-account] for this but you can use a personal user account just to try this reference architecture. Ensure that your organization allows access via the access token type you select.

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

## Project Configuration

You only need to complete the section for the option that you have selected (either option 1 or 2).

### Option 1: Bring your own project (BYOP)

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
  export GOOGLE_APPLICATION_CREDENTIALS=${CLOUDSDK_CONFIG:-${HOME}/.config/gcloud}/application_default_credentials.json
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

### Option 2: Terraform managed project

- Set the configuration variables

  ```
  nano ${MLP_BASE_DIR}/terraform/features/initialize/initialize.auto.tfvars
  ```

  ```
  environment_name = "dev"
  project = {
    billing_account_id = "XXXXXX-XXXXXX-XXXXXX"
    folder_id          = "############"
    name               = "mlp"
    org_id             = "############"
  }
  ```

  - `environment_name`: the name of the environment
  - `project.billing_account_id`: the billing account ID
  - `project.name`: the prefix for the display name of the project, the full name will be `<project.name>-<environment_name>`

  Enter either `project.folder_id` **OR** `project.org_id`

  - `project.folder_id`: the Google Cloud folder ID
  - `project.org_id`: the Google Cloud organization ID

- Authorize `gcloud`

  ```
  export GOOGLE_APPLICATION_CREDENTIALS=${CLOUDSDK_CONFIG:-${HOME}/.config/gcloud}/application_default_credentials.json
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

- Set the project environment variables in Cloud Shell

  ```
  MLP_PROJECT_ID=$(grep environment_project_id ${MLP_TYPE_BASE_DIR}/mlp.auto.tfvars | awk -F"=" '{print $2}' | xargs)
  ```

## Configure Identity-Aware Proxy (IAP)

Identity-Aware Proxy (IAP) lets you establish a central authorization layer for applications accessed by HTTPS, so you can use an application-level access control model instead of relying on network-level firewalls.

IAP policies scale across your organization. You can define access policies centrally and apply them to all of your applications and resources. When you assign a dedicated team to create and enforce policies, you protect your project from incorrect policy definition or implementation in any application.

For more information on IAP, see the [Identity-Aware Proxy documentation](https://cloud.google.com/iap/docs/concepts-overview#gke)

### Configure OAuth consent screen for IAP

For this guide we will configure a generic OAuth consent screen setup for internal use. Internal use means that only users within your organization can be granted IAM permissions to access the IAP secured applications and resource.

See the [Configuring the OAuth consent screen documenation](https://developers.google.com/workspace/guides/configure-oauth-consent) for additional information

**NOTE: These steps only need to be completed once for a project.**

- Go to [APIs & Services](https://console.cloud.google.com/apis/dashboard?) > [OAuth consent screen](https://console.cloud.google.com/apis/credentials/consent) configuration page.
- Select **Internal** for the **User Type**
- Click **CREATE**
- Enter **IAP Secured Application** for the the **App name**
- Enter an email address for the **User support email**
- Enter an email address for the **Developer contact information**
- Click **SAVE AND CONTINUE**
- Leave the default values for **Scopes**
- Click **SAVE AND CONTINUE**
- On the **Summary** page, click **BACK TO DASHBOARD**
- The **OAuth consent screen** should now look like this:
  ![oauth consent screen](/best-practices/ml-platform/docs/images/platform/oauth-consent-screen.png)

### Default IAP access

For simplicity, in this guide access to the IAP secured applications will be configure to allow all users in the organization. Access can be configured per IAP application or resources.

- Set the IAP allow domain

  ```
  IAP_DOMAIN=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" | awk -F@ '{print $2}')
  echo "IAP_DOMAIN=${IAP_DOMAIN}"
  ```

  **If the domain of the active `gcloud` user is different from the organization that the `MLP_PROJECT_ID` project is in, you will need to manually set `IAP_DOMAIN` environment variable**

  ```
  IAP_DOMAIN=<MLP_PROJECT_ID organization domain>
  ```

- Set the IAP domain in the configuration file

  ```
  sed -i '/^iap_domain[[:blank:]]*=/{h;s/=.*/= "'"${IAP_DOMAIN}"'"/};${x;/^$/{s//iap_domain             = "'"${IAP_DOMAIN}"'"/;H};x}' ${MLP_TYPE_BASE_DIR}/mlp.auto.tfvars
  ```

## Create the resources

Before running Terraform, make sure that the Service Usage API is enable.

- Enable Service Usage API

  `gcloud services enable serviceusage.googleapis.com`

- Ensure the endpoint is not in a deleted state

  ```
  MLP_PROJECT_ID=$(grep environment_project_id ${MLP_TYPE_BASE_DIR}/mlp.auto.tfvars | awk -F"=" '{print $2}' | xargs)
  gcloud endpoints services undelete ray-dashboard.ml-team.mlp.endpoints.${MLP_PROJECT_ID}.cloud.goog --quiet 2>/dev/null
  ```

- Create the resources

  ```
  cd ${MLP_TYPE_BASE_DIR} && \
  terraform init && \
  terraform plan -input=false -var github_token="$(tr --delete '\n' < ${HOME}/secrets/mlp-github-token)" -out=tfplan && \
  terraform apply -input=false tfplan && \
  rm tfplan
  ```

  See [Create resources errors](#create-resources-errors) in the Troubleshooting section if the apply does not complete successfully.

## Review the resources

### GKE clusters and ConfigSync

- Go to Google Cloud Console, click on the navigation menu and click on [Kubernetes Engine](https://console.cloud.google.com/kubernetes) > [Clusters](https://console.cloud.google.com/kubernetes/list). You should see one cluster.

- Go to Google Cloud Console, click on the navigation menu and click on [Kubernetes Engine](https://console.cloud.google.com/kubernetes) > [Config](https://console.cloud.google.com/kubernetes/config_management/dashboard).
  If you haven't enabled GKE Enterprise in the project earlier, Click `LEARN AND ENABLE` button and then `ENABLE GKE ENTERPRISE`. You should see a RootSync and RepoSync object.
  ![configsync](/best-practices/ml-platform/docs/images/platform/configsync.png)

### Software installed via RepoSync and RootSync

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

- Open the `ml-team` Ray dashboard

  ```
  MLP_PROJECT_ID=$(grep environment_project_id ${MLP_TYPE_BASE_DIR}/mlp.auto.tfvars | awk -F"=" '{print $2}' | xargs)
  echo -e "\nml-team Ray dashboard: https://ray-dashboard.ml-team.mlp.endpoints.${MLP_PROJECT_ID}.cloud.goog\n"
  ```

  > If you get `ERR_CONNECTION_CLOSED` or `ERR_CONNECTION_RESET` when trying to go to the Ray dashboard, the [Gateway](https://console.cloud.google.com/kubernetes/gateways) is still being provisioned. Retry in a couple of minutes.

  > If you get `ERR_SSL_VERSION_OR_CIPHER_MISMATCH` when trying to go to the Ray dashboard, the [SSL certificate](https://console.cloud.google.com/security/ccm/list/lbCertificates) is still being provisioned. Retry in a couple of minutes.

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
  examples/platform/sandbox/backend.tf \
  examples/platform/sandbox/mlp.auto.tfvars \
  terraform/features/initialize/backend.tf \
  terraform/features/initialize/backend.tf.bucket \
  terraform/features/initialize/initialize.auto.tfvars
  ```

- Remove Terraform files and temporary files

  ```
  cd ${MLP_BASE_DIR} && \
  rm -rf \
  examples/platform/sandbox/.terraform \
  examples/platform/sandbox/.terraform.lock.hcl \
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
