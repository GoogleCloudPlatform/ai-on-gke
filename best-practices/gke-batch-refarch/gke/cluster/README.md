# Reference implementation for regional GKE accelerator clusters

## Pull the source code

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
  cd examples/cluster && \
  export MLP_TYPE_BASE_DIR=$(pwd) && \
  echo "export MLP_TYPE_BASE_DIR=${MLP_TYPE_BASE_DIR}" >> ${HOME}/.bashrc
  ```

## Configure

```
vi ${MLP_TYPE_BASE_DIR}/shared_config/cluster.auto.tfvars
```

```
enable_private_endpoint = false
environment_name        = "env"
environment_project_id  = "PROJECT_ID"
region                  = "us-central1"
```

## Apply

```
cd ${MLP_TYPE_BASE_DIR}/initialize && \
terraform init && \
terraform apply -input=false
```

```
cd ${MLP_TYPE_BASE_DIR}/networking && \
terraform init && \
terraform apply -input=false
```

```
cd ${MLP_TYPE_BASE_DIR}/container_cluster && \
terraform init && \
terraform apply -input=false
```

```
cd ${MLP_TYPE_BASE_DIR}/workloads && \
terraform init && \
terraform apply -input=false
```

## Destroy

```
cd ${MLP_TYPE_BASE_DIR}/workloads && \
terraform destroy -auto-approve
```

```
cd ${MLP_TYPE_BASE_DIR}/container_cluster && \
terraform destroy -auto-approve
```

```
cd ${MLP_TYPE_BASE_DIR}/networking && \
terraform destroy -auto-approve
```

```
cd ${MLP_TYPE_BASE_DIR}/initialize && \
terraform destroy -auto-approve
```
