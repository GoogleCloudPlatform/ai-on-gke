# Reference implementation for regional GKE accelerator clusters

## Pull the source code

- Clone the repository and change directory to the guide directory

  ```
  git clone https://github.com/GoogleCloudPlatform/ai-on-gke && \
  cd ai-on-gke/best-practices/ml-platform
  ```

- Set environment variables

  ```
  export ACP_BASE_DIR=$(pwd) && \
  echo "export ACP_BASE_DIR=${ACP_BASE_DIR}" >> ${HOME}/.bashrc
  ```

  ```
  cd examples/cluster && \
  export ACP_CLUSTER_BASE_DIR=$(pwd) && \
  echo "export ACP_CLUSTER_BASE_DIR=${ACP_CLUSTER_BASE_DIR}" >> ${HOME}/.bashrc
  ```

## Configure

```
vi ${ACP_CLUSTER_BASE_DIR}/shared_config/cluster.auto.tfvars
```

```
cluster_name_prefix     = "batch"
enable_private_endpoint = false
environment_name        = "env"
environment_project_id  = "PROJECT_ID"
region                  = "us-central1"
```

## Apply

### Initialize

```
cd ${ACP_CLUSTER_BASE_DIR}/initialize && \
terraform init && \
terraform plan -input=false -out=tfplan && \
terraform apply -input=false tfplan && \
rm tfplan && \
cp backend.tf backend.tf.local && \
cp backend.tf.bucket backend.tf && \
terraform init -force-copy -migrate-state && \
rm -rf state
```

### Networking

```
cd ${ACP_CLUSTER_BASE_DIR}/networking && \
terraform init && \
terraform plan -input=false -out=tfplan && \
terraform apply -input=false tfplan && \
rm tfplan
```

### Container Cluster

```
cd ${ACP_CLUSTER_BASE_DIR}/container_cluster && \
terraform init && \
terraform plan -input=false -out=tfplan && \
terraform apply -input=false tfplan && \
rm tfplan
```

### Workloads

```
cd ${ACP_CLUSTER_BASE_DIR}/workloads && \
terraform init && \
terraform plan -input=false -out=tfplan && \
terraform apply -input=false tfplan && \
rm tfplan
```

## Destroy

### Workloads

```
cd ${ACP_CLUSTER_BASE_DIR}/workloads && \
terraform destroy -auto-approve && \
rm -rf .terraform/ .terraform.lock.hcl state/
```

### Container Cluster

```
cd ${ACP_CLUSTER_BASE_DIR}/container_cluster && \
terraform destroy -auto-approve && \
rm -rf .terraform/ .terraform.lock.hcl state/
```

### Networking

```
cd ${ACP_CLUSTER_BASE_DIR}/networking && \
terraform destroy -auto-approve && \
rm -rf .terraform/ .terraform.lock.hcl state/
```

### Initialize

```
cd ${ACP_CLUSTER_BASE_DIR}/initialize && \
TERRAFORM_BUCKET_NAME=$(grep bucket backend.tf | awk -F"=" '{print $2}' | xargs) && \
cp backend.tf.local backend.tf && \
terraform init -force-copy -lock=false -migrate-state && \
gsutil -m rm -rf gs://${TERRAFORM_BUCKET_NAME}/* && \
terraform destroy -auto-approve && \
rm -rf .terraform/ .terraform.lock.hcl state/
```

## Repository cleanup

```
rm -rf \
${ACP_CLUSTER_BASE_DIR}/initialize/.terraform/ \
${ACP_CLUSTER_BASE_DIR}/initialize/.terraform.lock.hcl \
${ACP_CLUSTER_BASE_DIR}/initialize/backend.tf.local \
${ACP_CLUSTER_BASE_DIR}/initialize/state/default.tfstatee \
${ACP_CLUSTER_BASE_DIR}/initialize/state/default.tfstate.backup \
${ACP_CLUSTER_BASE_DIR}/networking/.terraform/ \
${ACP_CLUSTER_BASE_DIR}/networking/.terraform.lock.hcl \
${ACP_CLUSTER_BASE_DIR}/container_cluster/.terraform/ \
${ACP_CLUSTER_BASE_DIR}/container_cluster/.terraform.lock.hcl \
${ACP_CLUSTER_BASE_DIR}/container_cluster/container_node_pool.tf \
${ACP_CLUSTER_BASE_DIR}/workloads/.terraform/ \
${ACP_CLUSTER_BASE_DIR}/workloads/.terraform.lock.hcl \
${ACP_CLUSTER_BASE_DIR}/kubeconfig/*

git restore \
${ACP_CLUSTER_BASE_DIR}/initialize/backend.tf \
${ACP_CLUSTER_BASE_DIR}/initialize/backend.tf.bucket
```
